# frozen_string_literal: true

module GDrive
  module Migration
    # Parent class for scan jobs that scan the source folder and update File and FolderMap records.
    class SourceScanJob < ScanJob
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
          self.class.perform_later(cluster_id: cluster_id, scan_task_id: new_scan_task.id)
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
          dest_parent_id = ancestor_tree_duplicator.ensure_tree(gdrive_file,
            skip_check_for_already_mapped_folders: skip_check_for_already_mapped_folders?)
        rescue AncestorTreeDuplicator::ParentFolderInaccessible => error
          operation.log(:error, "Ancestor inaccessible", file_id: gdrive_file.id, folder_id: error.folder_id)
          # We don't need to take any action here because a new folder with an inaccessible parent should
          # just be ignored as it's probably outside the migration tree.
          return false
        rescue Google::Apis::ClientError => error
          operation.log(:error, "Client error ensuring tree", file_id: file_id, message: error.to_s)
          # We don't need to take any action here because a client error on a new folder means
          # we should probably just ignore it.
          return false
        end
        true
      end

      def process_existing_folder(folder_map, gdrive_file)
        operation.log(:info, "Processing existing folder", src_id: folder_map.src_id, dest_id: folder_map.dest_id)

        if !gdrive_file.trashed && gdrive_file.name == folder_map.name && gdrive_file.parents[0] == folder_map.src_parent_id
          operation.log(:info, "No changes, returning", src_id: folder_map.src_id, dest_id: folder_map.dest_id)
          return true
        end

        if gdrive_file.trashed
          operation.log(:info, "Folder is in trash, deleting folder map", src_id: folder_map.src_id, dest_id: folder_map.dest_id)
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
          rescue AncestorTreeDuplicator::ParentFolderInaccessible => error
            # If getting the new dest folder ID fails, it likely means the the src folder
            # has been moved out of the migration tree or is otherwise inaccessible.
            # This shouldn't happen, I think, b/c we should get no file data in that case
            # and that is handled further up. But just in case, log and skip.
            operation.log(:error, "Ancestor inaccessible, skipping", src_id: folder_map.src_id, dest_id: folder_map.dest_id, ancestor_id: error.folder_id)
            return false
          rescue Google::Apis::ClientError => error
            operation.log(:error, "Client error ensuring tree, skipping", src_id: folder_map.src_id, dest_id: folder_map.dest_id, message: error.to_s)
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
        rescue Google::Apis::ClientError => error
          operation.log(:error, "Client error updating dest folder", src_id: folder_map.src_id, dest_id: folder_map.dest_id, message: error.to_s)
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
          operation.log(:info, "File has no parents, skipping", file_id: gdrive_file.id, name: gdrive_file.name)
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
          operation.log(:info, "File has been migrated, skipping", file_id: gdrive_file.id, status: gdrive_file.status)
          return
        end

        # parents.nil? means the item is no longer accessible.
        if gdrive_file.trashed || gdrive_file.parents.nil?
          operation.log(:info, "File is in trash, deleting record", file_id: gdrive_file.id)
          migration_file.update!(status: "disappeared")
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

      def add_file_error(migration_file, type, message)
        operation.log(:error, "File error", id: migration_file.id, type: type, message: message)
        migration_file.update!(status: "errored", error_type: type, error_message: message)
        scan.increment!(:error_count)
        if scan.error_count >= MIN_ERRORS_TO_CANCEL &&
            scan.error_count.to_f / scan.scanned_file_count > MAX_ERROR_RATIO
          cancel_scan(reason: "too_many_errors")
        end
      end
    end
  end
end
