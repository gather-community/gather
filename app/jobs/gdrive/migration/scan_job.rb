# frozen_string_literal: true

module GDrive
  module Migration
    # Scans for all files in the source drive folder.
    class ScanJob < BaseJob
      PAGE_SIZE = 100
      MIN_ERRORS_TO_CANCEL = 5
      MAX_ERROR_RATIO = 0.05
      FILE_FIELDS = "id,name,parents,mimeType,webViewLink,iconLink,modifiedTime,owners(emailAddress)," \
                    "capabilities(canEdit),shortcutDetails(targetId,targetMimeType),trashed"

      # If we get a not found error trying to find one of these, we should just terminate gracefully.
      DISAPPEARABLE_CLASSES = %w[GDrive::Migration::Operation GDrive::Migration::Scan
                                 GDrive::Migration::ScanTask].freeze

      attr_accessor :cluster_id, :scan_task, :scan, :operation, :ancestor_tree_duplicator

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
          operation.log(:info, "ScanJob starting", scan_task_id: scan_task_id)
          return if scan.cancelled?

          self.ancestor_tree_duplicator = AncestorTreeDuplicator.new(wrapper: wrapper, operation: operation)

          # We save the start page token now so that we can look back through any changes that we miss
          # during the scan operation.
          save_start_page_token if scan.full?

          do_scan_task
          check_for_completeness
        end
      rescue ActiveRecord::RecordNotFound => e
        class_name = e.message.match(/Couldn't find (.+) with/).captures[0]
        raise unless DISAPPEARABLE_CLASSES.include?(class_name)

        if operation
          operation.log(:error, e.message)
          operation.log(:info, "Exiting gracefully")
        else
          Rails.logger.error(e.message)
          Rails.logger.info("Exiting gracefully")
        end
      end

      private

      def save_start_page_token
        # Only do this once per operation
        self.class.with_lock(operation.id) do
          return if operation.reload.start_page_token.present?

          WebhookRegistrar.setup(operation, wrapper)
        end
      end

      def do_scan_task
        files, next_page_token, new_start_page_token = if scan.full?
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
          elsif new_start_page_token
            operation.log(:info, "Reached end of changes, updating start page token",
                          new_start_page_token: new_start_page_token)
            operation.update!(start_page_token: new_start_page_token)
          end
        end
      rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
        # If we hit an auth error, it is probably not going to resolve itself, and it
        # is not an issue with our code. So we stop the scan and notify the user.
        cancel_scan(reason: "auth_error")
      end

      def list_files_from_folder(folder_id)
        operation.log(:info, "Listing files from folder", folder_id: folder_id)
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
        [list.files, list.next_page_token, nil]
      end

      def list_files_from_changes
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
            delete_references_to(change.file_id)
            next
          end

          # If drive_id is present, it means this is a changes scan and we've pulled in
          # a change to a Shared Drive item. This could happen if someone migrated a file manually.
          # In any case, we don't care about these files anymore so delete any references if present.
          if change.file.drive_id.present?
            operation.log(:info, "Received change with drive_id, deleting references if present",
                          file_id: change.file_id, drive_id: change.file.drive_id)
            delete_references_to(change.file_id)
            next
          end

          # IMPORTANT: We don't check whether the changed file is within the source directory tree
          # because that would be slow, and we always assume that the migration user only has access
          # to the source migration tree anyway.
          gdrive_files << change.file
        end
        [gdrive_files, list.next_page_token, list.new_start_page_token]
      end

      def process_file(gdrive_file)
        operation.log(:info, "Processing item", id: gdrive_file.id, name: gdrive_file.name,
                                                type: gdrive_file.mime_type, owner: gdrive_file.owners[0].email_address)

        # Sometimes a changes batch will include the src folder, which is redundant.
        # We should never get to this point in the full scan with the gdrive_file as the src_folder either.
        if gdrive_file.id == operation.src_folder_id
          operation.log(:info, "Item is operation src folder, skipping")
          return
        end

        scan.increment!(:scanned_file_count)

        if gdrive_file.mime_type == GDrive::FOLDER_MIME_TYPE
          processing_folder_succeeded = if (folder_map = FolderMap.find_by(src_id: gdrive_file.id))
                                          process_existing_folder(folder_map, gdrive_file)
                                        else
                                          process_new_folder(gdrive_file)
                                        end

          return if scan.changes? || !processing_folder_succeeded

          operation.log(:info, "Scheduling scan task for subfolder", folder_id: gdrive_file.id)
          new_scan_task = scan.scan_tasks.create!(folder_id: gdrive_file.id)
          ScanJob.perform_later(cluster_id: cluster_id, scan_task_id: new_scan_task.id)
        else
          migration_file = operation.files.find_by(external_id: gdrive_file.id)
          if migration_file.nil?
            process_new_file(gdrive_file)
          else
            process_existing_file(gdrive_file, migration_file)
          end
        end
      end

      # Creates dest folder to match given src folder.
      # Creates folder map.
      # Returns the new folder map, or nil if any API calls on source file fail.
      def process_new_folder(gdrive_file)
        operation.log(:info, "Processing new folder", src_id: gdrive_file.id)
        begin
          # The AncestorTreeDuplicator makes use of existing FolderMap records as part of its algorithm
          # but it treats them skeptically by default, making sure that the destination folder still actually
          # exists before proceeding. But we don't need to check this when we are
          # doing the initial scan since we will have just created it.
          ancestor_tree_duplicator.ensure_tree(gdrive_file,
                                               skip_check_for_already_mapped_folders: scan.full?)
        rescue AncestorTreeDuplicator::ParentFolderInaccessible => e
          operation.log(:error, "Ancestor inaccessible", file_id: gdrive_file.id, folder_id: e.folder_id)
          # We don't need to take any action here because a new folder with an inaccessible parent should
          # just be ignored as it's probably outside the migration tree.
          return false
        rescue Google::Apis::ClientError => e
          operation.log(:error, "Client error ensuring tree", file_id: file_id, message: e.to_s)
          # We don't need to take any action here because a client error on a new folder means
          # we should probably just ignore it.
          return false
        end
        true
      end

      def process_existing_folder(folder_map, gdrive_file)
        operation.log(:info, "Processing existing folder", src_id: folder_map.src_id,
                                                           dest_id: folder_map.dest_id)

        if !gdrive_file.trashed && gdrive_file.name == folder_map.name && gdrive_file.parents[0] == folder_map.src_parent_id
          operation.log(:info, "No changes, returning", src_id: folder_map.src_id,
                                                        dest_id: folder_map.dest_id)
          return true
        end

        if gdrive_file.trashed
          operation.log(:info, "Folder is in trash, deleting folder map", src_id: folder_map.src_id,
                                                                          dest_id: folder_map.dest_id)
          folder_map.destroy
          return true
        end

        folder_map.name = gdrive_file.name
        dest_add_parents = []
        dest_remove_parents = []
        old_src_parent_id = folder_map.src_parent_id
        new_src_parent_id = gdrive_file.parents && gdrive_file.parents[0]

        # This means src folder moved!
        if new_src_parent_id != old_src_parent_id
          old_dest_parent_id = folder_map.dest_parent_id

          begin
            new_dest_parent_id = ancestor_tree_duplicator.ensure_tree(new_src_parent_id)
          rescue AncestorTreeDuplicator::ParentFolderInaccessible => e
            # If getting the new dest folder ID fails, it likely means the the src folder
            # has been moved out of the migration tree or is otherwise inaccessible.
            # This shouldn't happen, I think, b/c we should get no file data in that case
            # and that is handled further up. But just in case, log and skip.
            operation.log(:error, "Ancestor inaccessible, skipping", src_id: folder_map.src_id,
                                                                     dest_id: folder_map.dest_id, ancestor_id: e.folder_id)
            return false
          rescue Google::Apis::ClientError => e
            operation.log(:error, "Client error ensuring tree, skipping", src_id: folder_map.src_id,
                                                                          dest_id: folder_map.dest_id, message: e.to_s)
            return false
          end

          dest_add_parents << new_dest_parent_id
          dest_remove_parents << old_dest_parent_id

          folder_map.src_parent_id = new_src_parent_id
          folder_map.dest_parent_id = new_dest_parent_id
        end

        begin
          # This could fail if we don't have access to the dest folder anymore, or if the
          # add or remove parents values are invalid. This could all happen if our records are out of date somehow.
          operation.log(:info, "Updating dest folder", src_id: folder_map.src_id, dest_id: folder_map.dest_id)
          wrapper.update_file(folder_map.dest_id,
                              Google::Apis::DriveV3::File.new(name: gdrive_file.name),
                              add_parents: dest_add_parents,
                              remove_parents: dest_remove_parents,
                              supports_all_drives: true)
          folder_map.save!
        rescue Google::Apis::ClientError => e
          operation.log(:error, "Client error updating dest folder", src_id: folder_map.src_id,
                                                                     dest_id: folder_map.dest_id, message: e.to_s)
          return false
        end
        true
      end

      def process_new_file(gdrive_file)
        operation.log(:info, "Processing new file", id: gdrive_file.id)

        if gdrive_file.trashed
          operation.log(:info, "File is in trash, skipping", file_id: gdrive_file.id, name: gdrive_file.name)
          return
        end

        if gdrive_file.parents.nil?
          operation.log(:info, "File has no parents, skipping", file_id: gdrive_file.id,
                                                                name: gdrive_file.name)
          return
        end

        operation.log(:info, "File not found, creating", file_id: gdrive_file.id, name: gdrive_file.name)
        operation.files.create!(
          external_id: gdrive_file.id,
          name: gdrive_file.name,
          parent_id: gdrive_file.parents[0],
          mime_type: gdrive_file.mime_type,
          owner: gdrive_file.owners[0].email_address,
          shortcut_target_id: gdrive_file.shortcut_details&.target_id,
          shortcut_target_mime_type: gdrive_file.shortcut_details&.target_mime_type,
          status: "pending",
          icon_link: gdrive_file.icon_link,
          web_view_link: gdrive_file.web_view_link,
          modified_at: gdrive_file.modified_time
        )
      end

      def process_existing_file(gdrive_file, migration_file)
        operation.log(:info, "Processing existing file", file_id: gdrive_file.id)

        # If file has already been migrated, we don't care about any changes to it
        # since the new file (if applicable) is considered to be the canonical copy.
        if migration_file.migrated?
          operation.log(:info, "File has been migrated, skipping", file_id: gdrive_file.id,
                                                                   status: gdrive_file.status)
          return
        end

        # parents.nil? means the item is no longer accessible.
        if gdrive_file.trashed || gdrive_file.parents.nil?
          operation.log(:info, "File is in trash, deleting record", file_id: gdrive_file.id)
          migration_file.destroy
          return
        end

        operation.log(:info, "Updating record", file_id: gdrive_file.id)
        migration_file.name = gdrive_file.name
        migration_file.owner = gdrive_file.owners[0].email_address
        migration_file.modified_at = gdrive_file.modified_time
        migration_file.parent_id = gdrive_file.parents[0]
        migration_file.shortcut_target_id = gdrive_file.shortcut_details&.target_id
        migration_file.shortcut_target_mime_type = gdrive_file.shortcut_details&.target_mime_type
        migration_file.save!
      end

      def delete_references_to(id)
        deleted = operation.folder_maps.where(src_id: id).destroy_all
        operation.log(:info, "Deleted #{deleted.size} folder maps") if deleted.any?
        deleted = operation.files.where(external_id: id).destroy_all
        operation.log(:info, "Deleted #{deleted.size} files") if deleted.any?
      end

      def add_file_error(migration_file, type, message)
        operation.log(:error, "File error", id: migration_file.id, type: type, message: message)
        migration_file.update!(status: "errored", error_type: type, error_message: message)
        scan.increment!(:error_count)
        if scan.error_count >= MIN_ERRORS_TO_CANCEL &&
            scan.error_count.to_f / scan.scanned_file_count > MAX_ERROR_RATIO
          cancel_scan(reason: "too_many_errors")
        end
      end

      def scan_next_page(next_page_token)
        operation.log(:info, "Creating scan task for next page")
        new_task = scan.scan_tasks.create!(
          # This may be nil if we are doing a changes scan.
          folder_id: scan_task.folder_id,
          page_token: next_page_token
        )
        ScanJob.perform_later(cluster_id: cluster_id, scan_task_id: new_task.id)
      end

      def ensure_scan_status_in_progress_unless_cancelled
        # We need a critical section here because otherwise we could have a
        # separate job that updates status to cancelled after we check
        # but before we set to "in_progress". We would then wipe out the cancellation.
        self.class.with_lock(operation.id) do
          scan.update!(status: "in_progress") unless scan.reload.cancelled?
        end
      end

      def cancel_scan(reason:)
        self.class.with_lock(operation.id) do
          operation.log(:info, "Cancelling scan", reason: reason)
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
            operation.log(:info, "No more scan task exists for this scan, marking complete")
            scan.update!(status: "complete")

            if scan.full?
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

      def wrapper
        return @wrapper if @wrapper

        # We build the wrapper using the main config because we are scanning the
        # folder via the Google Workspace user account. This allows us to scan all
        # the files because we have drive (not drive.file) scope on that app.
        main_config = MainConfig.find_by(community: operation.community)
        @wrapper = Wrapper.new(config: main_config, google_user_id: main_config.org_user_id)
      end
    end
  end
end
