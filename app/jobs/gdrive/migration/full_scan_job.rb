# frozen_string_literal: true

module GDrive
  module Migration
    # Scans for all files in the source drive folder.
    class FullScanJob < ScanJob
      protected

      def skip_check_for_already_mapped_folders?
        true
      end

      def before_scan_start
        # We save the start page token now so that we can look back through any changes that we miss
        # during the scan operation.
        self.class.with_lock(operation.id) do
          return if operation.reload.start_page_token.present?
          WebhookRegistrar.setup(operation, wrapper)
        end
      end

      def do_scan_task
        files, next_page_token = list_files_from_folder(scan_task.folder_id)

        # Update scan status now and then each time we go through loop.
        # We do it here just in case we are skipping all the files we fetched on the
        # first page.
        ensure_scan_status_in_progress_unless_cancelled

        # Process files one by one, but check after each one if another task thread
        # has hit too many errors and cancelled the scan.
        files.each do |gdrive_file|
          if scan.cancelled?
            operation.log(:info, "Scan has been cancelled, exiting loop")
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

      def after_scan_complete
        # We can register for this now since we are finished scanning.
        # We saved the start page token earlier so that we will get any changes
        # we missed during scanning.
        WebhookRegistrar.register(operation, wrapper)

        # If main scan job is finishing, we should run a change scan because changes
        # may have been piling up (and we ignore them during the main scan)
        self.class.enqueue_change_scan_job(operation)
      end
    end
  end
end
