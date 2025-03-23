# frozen_string_literal: true

module GDrive
  module Migration
    # Scans items returned from changes API
    class ChangesScanJob < SourceScanJob
      def self.enqueue(operation)
        scan = operation.scans.create!(scope: "changes")
        scan_task = scan.scan_tasks.create!(page_token: operation.start_page_token)
        ChangesScanJob.perform_later(cluster_id: operation.cluster_id, scan_task_id: scan_task.id)
      end

      protected

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

      # We override the list_files function to get changes from the changes API instead of
      # from the folder_id, which is not set fo this kind of job.
      def list_files
        operation.log(:info, "Listing files from changes", page_token: scan_task.page_token)
        list = wrapper.list_changes(
          scan_task.page_token,
          fields: "changes(fileId,file(#{FILE_FIELDS},driveId)),nextPageToken,newStartPageToken",
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

        gdrive_files = []
        list.changes.each do |change|
          # If no file is present at all, it means we no longer have access to this file
          # and we should delete any reference we have to it.
          if change.file.nil?
            operation.log(:info, "Received change with no file info, deleting references if present",
              file_id: change.file_id)
            update_references_to_missing_file(change.file_id)
            next
          end

          # If drive_id is present, it means this is a changes scan and we've pulled in
          # a change to a Shared Drive item. This could happen if someone migrated a file manually.
          # In any case, we don't care about these files anymore so delete any references if present.
          if change.file.drive_id.present?
            operation.log(:info, "Received change with drive_id, deleting references if present",
              file_id: change.file_id, drive_id: change.file.drive_id)
            update_references_to_missing_file(change.file_id)
            next
          end

          # IMPORTANT: We don't check whether the changed file is within the source directory tree
          # because that would be slow, and we always assume that the migration user only has access
          # to the source migration tree anyway.
          gdrive_files << change.file
        end

        # If next_page_token is present then we are going to keep scanning so
        # no need to save new_start_page_token yet.
        if !list.next_page_token && list.new_start_page_token
          operation.log(:info, "Reached end of changes, updating start page token",
            new_start_page_token: list.new_start_page_token)
          operation.update!(start_page_token: list.new_start_page_token)
        end

        [gdrive_files, list.next_page_token]
      end

      private

      def update_references_to_missing_file(id)
        deleted = operation.folder_maps.where(src_id: id).destroy_all
        if deleted.any?
          operation.log(:info, "Deleted #{deleted.size} folder maps")
        end
        missing_files = operation.files.where(external_id: id)
        missing_files.update_all(status: "disappeared")
        updated_count = missing_files.count
        if updated_count > 0
          operation.log(:info, "Updated status of #{updated_count} files to disappeared")
        end
      end
    end
  end
end
