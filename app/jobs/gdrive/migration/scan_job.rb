# frozen_string_literal: true

module GDrive
  module Migration
    # Scans for all files in the source drive folder.
    class ScanJob < BaseJob
      PAGE_SIZE = 100
      MIN_ERRORS_TO_CANCEL = 5
      MAX_ERROR_RATIO = 0.05
      FILE_FIELDS = "id,name,parents,mimeType,webViewLink,iconLink,modifiedTime,owners(emailAddress),capabilities(canEdit)"

      # If we get a not found error trying to find one of these, we should just terminate gracefully.
      DISAPPEARABLE_CLASSES = %w[GDrive::Migration::Operation GDrive::Migration::Scan GDrive::Migration::ScanTask].freeze

      attr_accessor :cluster_id, :scan_task, :scan, :operation

      def self.with_lock(operation_id, &block)
        # We use the operation and not the scan as the context since there could be a race condition
        # between several scans running at the same time for the same operation.
        lock_name = "gdrive-migration-scan-operation-#{operation_id}"
        Operation.with_advisory_lock!(lock_name, timeout_seconds: 120, disable_query_cache: true) do
          block.call
        end
      end

      def self.enqueue_change_scan_job(operation)
        scan = operation.scans.create!(scope: "changes")
        scan_task = scan.scan_tasks.create!(page_token: operation.start_page_token)
        ScanJob.perform_later(cluster_id: operation.cluster_id, scan_task_id: scan_task.id)
      end

      def perform(cluster_id:, scan_task_id:)
        self.cluster_id = cluster_id
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          self.scan_task = ScanTask.find(scan_task_id)
          self.scan = scan_task.scan
          self.operation = scan.operation
          Rails.logger.info("ScanJob starting", operation_id: operation.id, scan_task_id: scan_task_id)
          return if scan.cancelled?

          # We save the start page token now so that we can look back through any changes that we miss
          # during the scan operation.
          save_start_page_token if scan.full?

          do_scan_task
          check_for_completeness
        end
      rescue ActiveRecord::RecordNotFound => error
        class_name = error.message.match(/Couldn't find (.+) with/).captures[0]
        raise unless DISAPPEARABLE_CLASSES.include?(class_name)
        Rails.logger.error(error.message)
        Rails.logger.info("Exiting gracefully")
      end

      private

      def save_start_page_token
        # Only do this once per operation
        self.class.with_lock(operation.id) do
          return if operation.reload.start_page_token.present?

          Rails.logger.info("Getting start_page_token", operation_id: operation.id)
          start_page_token = wrapper.get_changes_start_page_token
          operation.update!(
            # We can setup the channel ID and the secret now too
            # as they are just random tokens and won't change.
            webhook_channel_id: SecureRandom.uuid,
            webhook_secret: SecureRandom.hex,
            start_page_token: start_page_token
          )
        end
      end

      def do_scan_task
        files, next_page_token = if scan.full?
          list_files_from_folder(scan_task.folder_id)
        else
          list_files_from_changes
        end

        # Update scan status now and then each time we go through loop.
        # We do it here just in case we are skipping all the files we fetched on the
        # first page.
        ensure_scan_status_in_progress_unless_cancelled

        # Process files one by one, but check after each one if another task thread
        # has hit too many errors and cancelled the scan.
        files.each do |gdrive_file|
          if scan.cancelled?
            Rails.logger.info("Scan has been cancelled, exiting loop")
            break
          end
          process_file(gdrive_file)
          ensure_scan_status_in_progress_unless_cancelled
        end

        # We don't need a critical section/advisory lock here because in the worst case, if there is a
        # race condition we might schedule an extra job, but when it actually runs it will notice
        # the cancelled state before it gets very far.
        unless scan.reload.cancelled?
          scan_next_page(next_page_token)
        end
      rescue Google::Apis::AuthorizationError
        # If we hit an auth error, it is probably not going to resolve itself, and it
        # is not an issue with our code. So we stop the scan and notify the user.
        cancel_scan(reason: "auth_error")
      end

      def list_files_from_folder(folder_id)
        list = wrapper.list_files(
          q: "'#{scan_task.folder_id}' in parents and trashed = false",
          fields: "files(#{FILE_FIELDS}),nextPageToken",
          order_by: "folder,name",
          include_items_from_all_drives: true,
          supports_all_drives: true,
          page_token: scan_task.page_token,
          page_size: PAGE_SIZE
        )
        [list.files, list.next_page_token]
      end

      def list_files_from_changes
        list = wrapper.list_changes(
          scan_task.page_token,
          fields: "changes(file(#{FILE_FIELDS},driveId)),nextPageToken",
          # Even though on change scans we only care about files from My Drive,
          # we need to include items from all drives because that is how we find out whether
          # something is in a shared drive or not. For some reason, the API still returns changes
          # from shared drives regardless of these booleans—it just doesn't tell us what
          # drive they're from /shrug.
          include_items_from_all_drives: true,
          supports_all_drives: true,
          page_size: PAGE_SIZE,
          include_corpus_removals: true,
          include_removed: true,
          spaces: "drive"
        )

        # If drive_id is present, it means this is a changes scan and we've pulled in
        # a change to a Shared Drive item, which we don't care about.
        [list.changes.select { |c| c.file.drive_id.nil? }.map(&:file), list.next_page_token]
      end

      def process_file(gdrive_file)
        Rails.logger.info("Processing file", id: gdrive_file.id, name: gdrive_file.name,
          type: gdrive_file.mime_type, owner: gdrive_file.owners[0].email_address)
        scan.increment!(:scanned_file_count)

        if gdrive_file.mime_type == GDrive::FOLDER_MIME_TYPE
          return unless process_new_folder(gdrive_file)

          return if scan.changes?

          Rails.logger.info("Scheduling scan task for subfolder", folder_id: gdrive_file.id)
          new_scan_task = scan.scan_tasks.create!(folder_id: gdrive_file.id)
          ScanJob.perform_later(cluster_id: cluster_id, scan_task_id: new_scan_task.id)
        else
          operation.files.find_or_create_by!(external_id: gdrive_file.id) do |file|
            Rails.logger.info("File not found, creating")
            file.name = gdrive_file.name
            file.parent_id = gdrive_file.parents[0]
            file.mime_type = gdrive_file.mime_type
            file.owner = gdrive_file.owners[0].email_address
            file.status = "pending"
            file.icon_link = gdrive_file.icon_link
            file.web_view_link = gdrive_file.web_view_link
            file.modified_at = gdrive_file.modified_time
          end
        end
      end

      def process_new_folder(gdrive_file)
        dest_parent_id = lookup_dest_folder_id(gdrive_file.parents[0])

        return false if dest_parent_id.nil?

        dest_folder = Google::Apis::DriveV3::File.new(name: gdrive_file.name, parents: [dest_parent_id],
          mime_type: GDrive::FOLDER_MIME_TYPE)
        dest_folder = wrapper.create_file(dest_folder, fields: "id", supports_all_drives: true)

        FolderMap.create!(operation: operation, src_parent_id: gdrive_file.parents[0],
          src_id: gdrive_file.id, dest_parent_id: dest_parent_id, dest_id: dest_folder.id,
          name: gdrive_file.name)
      end

      def lookup_dest_folder_id(src_id)
        return operation.dest_folder_id if src_id == operation.src_folder_id
        Rails.logger.info("Looking up dest folder id")
        folder_map = FolderMap.find_by(operation: operation, src_id: src_id)
        folder_map&.dest_id
      end

      def add_file_error(migration_file, type, message)
        Rails.logger.error("File error", id: migration_file.id, type: type, message: message)
        migration_file.update!(status: "errored", error_type: type, error_message: message)
        scan.increment!(:error_count)
        if scan.error_count >= MIN_ERRORS_TO_CANCEL &&
            scan.error_count.to_f / scan.scanned_file_count > MAX_ERROR_RATIO
          cancel_scan(reason: "too_many_errors")
        end
      end

      def scan_next_page(next_page_token)
        if next_page_token
          Rails.logger.info("Creating scan task for next page")
          new_task = scan.scan_tasks.create!(
            # This may be nil if we are doing a changes scan.
            folder_id: scan_task.folder_id,
            page_token: next_page_token
          )
          ScanJob.perform_later(cluster_id: cluster_id, scan_task_id: new_task.id)
        end
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
          Rails.logger.info("Cancelling scan", reason: reason)
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
            Rails.logger.info("No more scan task exists for this scan, marking complete")
            scan.update!(status: "complete")

            if scan.full?
              # We can register for this now since we are finished scanning.
              # We saved the start page token earlier so that we will get any changes
              # we missed during scanning.
              register_webhook

              # If main scan job is finishing, we should run a change scan because changes
              # may have been piling up (and we ignore them during the main scan)
              self.class.enqueue_change_scan_job(operation)
            end
          end
        end
      end

      def register_webhook
        Rails.logger.info("Registering webhook", operation_id: operation.id)
        webhook_url_settings = Settings.gdrive&.migration&.changes_webhook_url
        url = Rails.application.routes.url_helpers.gdrive_migration_changes_webhook_url(
          host: webhook_url_settings&.host || Settings.url.host,
          port: webhook_url_settings&.port || Settings.url.port,
          protocol: "https"
        )
        wrapper.watch_change(operation.start_page_token,
          Google::Apis::DriveV3::Channel.new(
            id: operation.webhook_channel_id,
            token: operation.webhook_secret,
            address: url,
            type: "web_hook"
          ),
          include_items_from_all_drives: false,
          include_corpus_removals: true,
          include_removed: true,
          spaces: "drive")
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
    end
  end
end
