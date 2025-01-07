# frozen_string_literal: true

module GDrive
  module Migration
    class AncestorTreeDuplicator
      class ParentFolderInaccessible < StandardError
        attr_accessor :folder_id

        def initialize(message, folder_id:)
          super(message)
          self.folder_id = folder_id
        end
      end

      include ActiveModel::Model

      attr_accessor :wrapper, :operation

      # Ensures that the ancestor tree for the given folder also exists
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
      #
      # If raises Google::Apis::ClientError, this is most likely because the workspace user
      # doesn't have access to src_folder or src_folder doesn't exist.
      #
      # If skip_check_for_already_mapped_folders is specified, we will assume the destination
      # folder exists if a FolderMap exists. This is safer if we are confident that the
      # dest folder was recently created, as when we are doing the initial scan.
      def ensure_tree(src_folder_or_id, skip_check_for_already_mapped_folders: false)
        if src_folder_or_id.is_a?(String)
          src_folder_id = src_folder_or_id
          src_folder = nil
        else
          src_folder_id = src_folder_or_id.id
          src_folder = src_folder_or_id
        end

        Rails.logger.info("Ensuring folder tree", src_folder_id: src_folder_id)

        return operation.dest_folder_id if src_folder_id == operation.src_folder_id

        # Check for an existing and valid map before we create a new one
        if (map = FolderMap.find_by(src_id: src_folder_id))
          if skip_check_for_already_mapped_folders || folder_exists?(map.dest_id)
            return map.dest_id
          else
            Rails.logger.warn("Folder map dest folder missing", src_folder_id: src_folder_id, dest_folder_id: map.dest_id)
            map.destroy
          end
        else
          Rails.logger.warn("Folder map not found", src_folder_id: src_folder_id)
        end

        # If we get to this point, we either had no map at all or an invalid map, so we need to
        # find or create the destination folder.

        # The first thing we need is the src_folder's parent so that we know what folder on the destination
        # to find/create the destination folder in.
        # To get this, we need to load the src folder from the API, unless it was given to us in the method call.
        # This request could fail if the workspace user doesn't have access to src_folder or src_folder
        # doesn't exist. The error will bubble up to the caller in that case.
        src_folder ||= wrapper.get_file(src_folder_id, fields: "id,name,parents", supports_all_drives: true)

        # This can happen if we don't have access to the target folder's parent, or, rarely,
        # if it has no parents, like if somehow src_folder_id is the person's My Drive. Either way
        # it's unrecoverable.
        if src_folder.parents.blank?
          Rails.logger.error("Source folder parent inaccessible", src_folder_id: src_folder_id)
          message = "Parent of folder #{src_folder_id} is inaccessible"
          raise ParentFolderInaccessible.new(message, folder_id: src_folder_id)
        else
          src_parent_id = src_folder.parents[0]
          # Recurse to get the destination for the parent.
          dest_parent_id = ensure_tree(src_parent_id)

          # Try to find a matching folder. If we fail, create one.
          unless (dest_folder = find_folder_by_parent_id_and_name(dest_parent_id, src_folder.name))
            Rails.logger.warn("Dest folder not found, creating", src_folder_id: src_folder_id,
              dest_parent_id: dest_parent_id, name: src_folder.name)
            dest_folder = Google::Apis::DriveV3::File.new(name: src_folder.name, parents: [dest_parent_id],
              mime_type: GDrive::FOLDER_MIME_TYPE)
            # This should not fail b/c we just confirmed that the parent exists, and we are working inside
            # the shared drive.
            dest_folder = wrapper.create_file(dest_folder, fields: "id", supports_all_drives: true)
          end

          Rails.logger.info("Creating folder map", src_folder_id: src_folder_id, dest_folder_id: dest_folder.id)
          FolderMap.create!(operation: operation, name: src_folder.name,
            src_parent_id: src_parent_id, src_id: src_folder_id,
            dest_parent_id: dest_parent_id, dest_id: dest_folder.id)
          dest_folder.id
        end
      end

      private def folder_exists?(id)
        # We use a cache on this class to keep track of checks we've done so that we don't
        # check the same folder over and over in a short period of time.
        # Assumes that this will not be a long lived class, but that it will be used
        # for multiple calls over a short period.
        @folder_ids_that_exist ||= {}
        return true if @folder_ids_that_exist[id]

        begin
          match = wrapper.get_file(id, fields: "id,mimeType", supports_all_drives: true)
          return false if !match || match.mime_type != GDrive::FOLDER_MIME_TYPE
          @folder_ids_that_exist[match.id]
          true
        rescue Google::Apis::ClientError
          false
        end
      end

      private def find_folder_by_parent_id_and_name(parent_id, name)
        # This can only fail if our permissions are bad. So we let it bubble
        # up to the caller in that case.
        parent_id = parent_id.gsub("'") { "\\'" }
        name = name.gsub("'") { "\\'" }
        file_list = wrapper.list_files(
          q: "'#{parent_id}' in parents and " \
            "mimeType = '#{GDrive::FOLDER_MIME_TYPE}' and " \
            "trashed = false and " \
            "name = '#{name}'",
          fields: "files(id)",
          supports_all_drives: true,
          include_items_from_all_drives: true
        )
        file_list.files[0]
      end
    end
  end
end
