# frozen_string_literal: true

module GDrive
  module Migration
    class AncestorTreeDuplicator
      include Singleton

      class TargetNotInMigrationFolderError < StandardError
      end

      # Ensures that the ancestor tree we mapped for the given file also exists
      # in the new drive. Creates it if not.
      # Runs recursively. Returns the dest folder ID.
      # If a matching folder map can't be found, we trace the ancestors of
      # the given source folder until we:
      # 1. Find an ancestor with a matching folder map.
      #    In this case, we then go back down the ancestor lineage, creating the destination folders
      #    and the missing FolderMap records.
      # 2. Get to the root operation.src_folder_id.
      #    In this case we do the same as in case #1.
      # 3. Reach an ancestor that has no parents (e.g. My Drive)
      #    In this case, we raise a TargetNotInMigrationFolderError.
      def ensure_tree(operation, wrapper, src_folder_id)
        return operation.dest_folder_id if src_folder_id == operation.src_folder_id

        map = FolderMap.find_by(src_id: src_folder_id)
        if map
          map.dest_id
        else
          src_folder = wrapper.get_file(src_folder_id, fields: "id,name,parents", supports_all_drives: true)
          src_parent_id = src_folder.parents[0]
          if src_parent_id.nil?
            raise TargetNotInMigrationFolderError
          else
            dest_parent_id = ensure_duplicated_ancestor_tree(operation, wrapper, src_parent_id)
            dest_folder = Google::Apis::DriveV3::File.new(name: src_folder.name, parents: [dest_parent_id],
              mime_type: GDrive::FOLDER_MIME_TYPE)
            dest_folder = wrapper.create_file(dest_folder, fields: "id", supports_all_drives: true)
            FolderMap.create!(src_parent_id: src_parent_id, src_id: src_folder_id,
              dest_parent_id: dest_parent_id, dest_id: dest_folder.id)
            dest_folder.id
          end
        end
      end
    end
  end
end
