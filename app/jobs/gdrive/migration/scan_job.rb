# frozen_string_literal: true

module GDrive
  module Migration
    # Parent class for all types of ScanJob
    class ScanJob < BaseJob
      PAGE_SIZE = 100
      MIN_ERRORS_TO_CANCEL = 5
      MAX_ERROR_RATIO = 0.05
      FILE_FIELDS = "id,name,parents,mimeType,webViewLink,iconLink,modifiedTime,owners(emailAddress)," \
        "capabilities(canEdit),shortcutDetails(targetId,targetMimeType),trashed"

      # If we get a not found error trying to find one of these, we should just terminate gracefully.
      DISAPPEARABLE_CLASSES = %w[GDrive::Migration::Operation GDrive::Migration::Scan GDrive::Migration::ScanTask].freeze

      attr_accessor :cluster_id, :scan_task, :scan, :operation, :ancestor_tree_duplicator

      def self.with_lock(operation_id, &block)
        # We use the operation and not the scan as the context since there could be a race condition
        # between several scans running at the same time for the same operation.
        lock_name = "gdrive-migration-scan-operation-#{operation_id}"
        Operation.with_advisory_lock!(lock_name, timeout_seconds: 120, disable_query_cache: true) do
          block.call
        end
      end

      def perform(cluster_id:, scan_task_id:)
        self.cluster_id = cluster_id
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          self.scan_task = ScanTask.find(scan_task_id)
          self.scan = scan_task.scan
          self.operation = scan.operation
          scan.log(:info, "ScanJob starting", scan_task_id: scan_task_id)
          return if scan.cancelled?

          self.ancestor_tree_duplicator = AncestorTreeDuplicator.new(wrapper: wrapper, operation: operation)

          # Call a hook for subclasses
          before_scan_start

          do_scan_task
          check_for_completeness
        end
      rescue ActiveRecord::RecordNotFound => error
        class_name = error.message.match(/Couldn't find (.+) with/).captures[0]
        raise unless DISAPPEARABLE_CLASSES.include?(class_name)
        if operation
          scan.log(:error, error.message)
          scan.log(:info, "Exiting gracefully")
        else
          Rails.logger.error(error.message)
          Rails.logger.info("Exiting gracefully")
        end
      end

      protected

      def before_scan_start
      end

      def after_scan_complete
      end

      def skip_check_for_already_mapped_folders?
        false
      end

      def do_scan_task
        files, next_page_token = list_files

        # Update scan status now and then each time we go through loop.
        # We do it here just in case we are skipping all the files we fetched on the
        # first page.
        ensure_scan_status_in_progress_unless_cancelled

        # Process files one by one, but check after each one if another task thread
        # has hit too many errors and cancelled the scan.
        files.each do |gdrive_file|
          if scan.cancelled?
            scan.log(:info, "Scan has been cancelled, exiting loop")
            break
          end
          process_file(gdrive_file)
          ensure_scan_status_in_progress_unless_cancelled
        end

        # We don't need a critical section/advisory lock here because in the worst case, if there is a
        # race condition we might schedule an extra job, but when it actually runs it will notice
        # the cancelled state before it gets very far.
        unless scan.reload.cancelled?
          if next_page_token
            scan_next_page(next_page_token)
          end
        end
      rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
        # If we hit an auth error, it is probably not going to resolve itself, and it
        # is not an issue with our code. So we stop the scan and notify the user.
        cancel_scan(reason: "auth_error")
      end

      # Default implementation, lists files from folder
      def list_files
        folder_id = scan_task.folder_id
        scan.log(:info, "Listing files from folder", folder_id: folder_id)
        folder_id = folder_id.gsub("'") { "\\'" }
        list = wrapper.list_files(
          q: "'#{folder_id}' in parents and trashed = false",
          fields: "files(#{FILE_FIELDS}),nextPageToken",
          order_by: "folder,name",
          include_items_from_all_drives: true,
          supports_all_drives: true,
          page_token: scan_task.page_token,
          page_size: PAGE_SIZE
        )
        [list.files, list.next_page_token]
      end

      def scan_next_page(next_page_token)
        scan.log(:info, "Creating scan task for next page")
        new_task = scan.scan_tasks.create!(
          # This may be nil if we are doing a changes scan.
          folder_id: scan_task.folder_id,
          page_token: next_page_token
        )
        self.class.perform_later(cluster_id: cluster_id, scan_task_id: new_task.id)
      end

      def ensure_scan_status_in_progress_unless_cancelled
        # We need a critical section here because otherwise we could have a
        # separate job that updates status to cancelled after we check
        # but before we set to "in_progress". We would then wipe out the cancellation.
        self.class.with_lock(operation.id) do
          unless scan.reload.cancelled?
            scan.update!(status: "in_progress")
          end
        end
      end

      def cancel_scan(reason:)
        self.class.with_lock(operation.id) do
          scan.log(:info, "Cancelling scan", reason: reason)
          scan.update!(status: "cancelled", cancel_reason: reason)
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
        self.class.with_lock(operation.id) do
          scan_task.destroy
          # We need to check again if cancelled in case another job has cancelled
          # the operation.
          if ScanTask.where(scan: scan).none? && !scan.reload.cancelled?
            scan.log(:info, "No more scan task exists for this scan, marking complete")
            scan.update!(status: "complete")

            # Call a hook for subclasses
            after_scan_complete
          end
        end
      end

      def wrapper
        return @wrapper if @wrapper

        # We build the wrapper using the main config because we are scanning the
        # folder via the Google Workspace user account. This allows us to scan all
        # the files because we have drive (not drive.file) scope on that app.
        config = Config.find_by(community: operation.community)
        @wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id)
      end
    end
  end
end
