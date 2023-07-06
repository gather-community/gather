# frozen_string_literal: true

module GDrive
  module Migration
    # Ingests selected files by starring them and noting any unowned files.
    class ScanJob < BaseJob
      PAGE_SIZE = 100
      MAX_ERRORS = 5

      retry_on Google::Apis::ServerError

      attr_accessor :cluster_id, :scan_task, :operation

      def perform(cluster_id:, scan_task_id:)
        self.cluster_id = cluster_id
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          self.scan_task = ScanTask.find(scan_task_id)
          self.operation = scan_task.operation
          return if operation.cancelled?
          do_scan
          check_for_completeness
        end
      end

      private

      def do_scan
        file_list = wrapper.list_files(
          q: "'#{scan_task.folder_id}' in parents",
          fields: "files(id,name,mimeType,owners(emailAddress),capabilities(canEdit)),nextPageToken",
          order_by: "folder,name",
          supports_all_drives: true,
          page_token: scan_task.page_token,
          page_size: PAGE_SIZE,
          include_items_from_all_drives: true
        )

        # Process files one by one, but check after each one if another task thread
        # has hit too many errors and cancelled the operation.
        file_list.files.each do |gdrive_file|
          ensure_operation_status_in_progress_unless_cancelled
          break if operation.cancelled?
          process_file(gdrive_file)
        end

        # We don't need a critical section/advisory lock here because in the worst case, if there is a
        # race condition we might schedule an extra job, but when it actually runs it will notice
        # the cancelled state before it gets very far.
        unless operation.reload.cancelled?
          scan_next_page(file_list)
        end
      rescue Google::Apis::AuthorizationError
        # If we hit an auth error, it is probably not going to resolve itself, and it
        # is not an issue with our code. So we stop the migration operation and notify the user.
        cancel_operation(reason: "auth_error")
      end

      def process_file(gdrive_file)
        migration_file = operation.files.find_or_create_by!(external_id: gdrive_file.id) do |file|
          file.name = gdrive_file.name
          file.mime_type = gdrive_file.mime_type
          file.owner = gdrive_file.owners[0].email_address
          file.status = "pending"
        end
        if migration_file.folder?
          scan_task = operation.scan_tasks.create!(folder_id: gdrive_file.id)
          ScanJob.perform_later(cluster_id: cluster_id, scan_task_id: scan_task.id)
        else
          ensure_filename_tag(gdrive_file, migration_file)
        end
      end

      def ensure_filename_tag(gdrive_file, migration_file)
        return if gdrive_file.name.ends_with?(filename_suffix)

        if gdrive_file.capabilities.can_edit
          new_name = "#{gdrive_file.name}#{filename_suffix}"
          wrapper.update_file(gdrive_file.id, Google::Apis::DriveV3::File.new(name: new_name))
        else
          add_file_error(migration_file, :cant_edit,
            "#{wrapper.google_user_id} did not have edit permission")
        end
      end

      def add_file_error(migration_file, type, message)
        migration_file.update!(status: "error", error_type: type, error_message: message)
        operation.increment!(:error_count)
        if operation.error_count >= MAX_ERRORS
          cancel_operation(reason: "too_many_errors")
        end
      end

      def scan_next_page(file_list)
        if file_list.next_page_token
          new_task = operation.scan_tasks.create!(
            folder_id: scan_task.folder_id,
            page_token: file_list.next_page_token
          )
          ScanJob.perform_later(cluster_id: cluster_id, scan_task_id: new_task.id)
        end
      end

      def ensure_operation_status_in_progress_unless_cancelled
        # We need a critical section here because otherwise we could have a
        # separate job that updates status to cancelled after we check
        # but before we set to "in_progress". We would then wipe out the cancellation.
        with_lock do
          unless operation.reload.cancelled?
            operation.update!(status: "in_progress")
          end
        end
      end

      def cancel_operation(reason:)
        with_lock do
          operation.update!(status: "cancelled", cancel_reason: reason)
        end
      end

      def check_for_completeness
        # If there is only one ScanTask at this point, we know that
        # this has to be the last ScanTask, and if we are the last ScanTask in reality
        # then we know the query has to return only one remaining ScanTask.
        # We know this because we are in a
        # critical section (in the scope of this operation), so even if there
        # is another ScanJob running at the same time, it must have already
        # deleted its ScanTask, so there is not a chance of us thinking we are
        # not the last one when in fact we are.
        with_lock do
          scan_task.destroy
          # We need to check again if cancelled in case another job has cancelled
          # the operation.
          if ScanTask.where(operation: operation).none? && !operation.reload.cancelled?
            operation.update!(status: "complete")
          end
        end
      end

      def wrapper
        return @wrapper if @wrapper
        migration_config = operation.config

        # We build the wrapper using the main config because we are scanning the
        # folder via the Google Workspace user account. This allows us to scan all
        # the files because we have drive (not drive.file) scope on that app.
        main_config = MainConfig.find_by(community: migration_config.community)
        @wrapper = Wrapper.new(config: main_config, google_user_id: main_config.org_user_id)
      end

      def filename_suffix
        @filename_suffix ||= " [🚚#{operation.filename_tag}]"
      end

      def with_lock(&block)
        lock_name = "gdrive-migration-scan-operation-#{operation.id}"
        Operation.with_advisory_lock!(lock_name, timeout_seconds: 120, disable_query_cache: true) do
          block.call
        end
      end
    end
  end
end
