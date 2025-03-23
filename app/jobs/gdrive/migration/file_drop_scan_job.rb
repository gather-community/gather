# frozen_string_literal: true

module GDrive
  module Migration
    # For scanning new arrivals to the file drop drive during the migration process.
    class FileDropScanJob < ScanJob
      def process_file(gdrive_file)
        scan.log(:info, "Processing item", id: gdrive_file.id, name: gdrive_file.name,
          type: gdrive_file.mime_type)

        scan.increment!(:scanned_file_count)

        if gdrive_file.mime_type == GDrive::FOLDER_MIME_TYPE
          scan.log(:info, "Scheduling scan task for subfolder", folder_id: gdrive_file.id)
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

      def process_new_file(gdrive_file)
        scan.log(:info, "Unrecognized file, leaving file in drop drive",
          file_id: gdrive_file.id, name: gdrive_file.name)
      end

      def process_existing_file(gdrive_file, migration_file)
        scan.log(:info, "Processing recognized file", file_id: gdrive_file.id, name: gdrive_file.name)

        begin
          dest_folder_id = ancestor_tree_duplicator.ensure_tree(migration_file.parent_id)
        rescue AncestorTreeDuplicator::ParentFolderInaccessible => error
          scan.log(:error, "Ancestor inaccessible, leaving file in drop drive",
            file_id: gdrive_file.id, name: gdrive_file.name, folder_id: error.folder_id)
          return
        rescue Google::Apis::ClientError => error
          scan.log(:error, "Client error ensuring tree, leaving file in drop drive",
            file_id: gdrive_file.id, name: gdrive_file.name, message: error.to_s)
          return
        end

        begin
          scan.log(:info, "Moving file to final destination.", file_id: gdrive_file.id,
            dest_folder_id: dest_folder_id)

          # This should rarely fail because we have just checked the existence of the destination folder
          # and the file is in a shared drive we have access to. But just in case, we handle the error
          # and attempt to move to orphans in case of error.
          wrapper.update_file(gdrive_file.id,
            add_parents: dest_folder_id,
            remove_parents: gdrive_file.parents[0],
            supports_all_drives: true)
        rescue Google::Apis::ClientError => error
          scan.log(:error, "Client error moving file, leaving file in drop drive",
            file_id: gdrive_file.id, name: gdrive_file.name, message: error.to_s)
        end
        migration_file.update!(status: "transferred")
      end
    end
  end
end
