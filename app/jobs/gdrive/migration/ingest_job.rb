# frozen_string_literal: true

module GDrive
  module Migration
    # Ingests selected files by moving them to their new homes.
    class IngestJob < BaseJob
      retry_on Google::Apis::ServerError

      attr_accessor :consent_request, :operation, :main_wrapper, :migration_wrapper

      def perform(cluster_id:, community_id:, consent_request_id:)
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          self.consent_request = ConsentRequest.find(consent_request_id)
          self.operation = consent_request.operation
          main_config = MainConfig.find_by!(community_id: community_id)
          self.main_wrapper = Wrapper.new(config: main_config, google_user_id: main_config.org_user_id)
          migration_config = consent_request.config
          self.migration_wrapper = Wrapper.new(config: migration_config, google_user_id: @consent_request.google_email)
          ensure_temp_drive
          ingest_files
          files_remaining = File.pending.owned_by(consent_request.google_email).count
          status = files_remaining.zero? ? "done" : "in_progress"
          consent_request.update!(status: status, ingest_status: "done", file_count: files_remaining)
        end
      end

      private

      class FolderMapNotFoundError < StandardError
      end

      # This is a separate class method so we can stub it in tests.
      def self.random_request_id
        SecureRandom.uuid
      end

      def ensure_temp_drive
        return if consent_request.temp_drive_id.present?

        temp_drive = Google::Apis::DriveV3::Drive.new(name: "Migration Temp Drive #{consent_request.id}")
        Rails.logger.info("Creating temp drive '#{temp_drive.name}")
        temp_drive = main_wrapper.create_drive(self.class.random_request_id, temp_drive)

        Rails.logger.info("Adding temp drive write permission for #{consent_request.google_email}")
        permission = Google::Apis::DriveV3::Permission.new(type: "user", email_address: consent_request.google_email,
          role: "writer")
        main_wrapper.create_permission(temp_drive.id, permission, supports_all_drives: true, send_notification_email: false)

        consent_request.update!(temp_drive_id: temp_drive.id)
      end

      # Ensures that the ancestor tree we mapped for the given file also exists
      # in the new drive. Creates it if not.
      # Runs recursively. Returns the dest folder ID, or nil if a matching
      # FolderMap couldn't be found.
      def ensure_duplicated_ancestor_tree(src_folder_id)
        return operation.dest_folder_id if src_folder_id == operation.src_folder_id

        map = FolderMap.find_by(src_id: src_folder_id)
        if map.nil?
          raise FolderMapNotFoundError, "No map found for #{src_folder_id}"
        end

        if map.dest_id
          map.dest_id
        else
          # If no dest ID, it hasn't been created yet so we need to create it.
          # We first need to get the parent_id in the destination tree.
          # If the source folder parent is the operation src_folder_id, we don't need to
          # recurse because we know the destination parent ID is just
          # the operation dest_folder_id.
          dest_parent_id = if map.src_parent_id == operation.src_folder_id
            operation.dest_folder_id
          else
            ensure_duplicated_ancestor_tree(map.src_parent_id)
          end
          return nil if dest_parent_id.nil?

          dest_folder = Google::Apis::DriveV3::File.new(name: map.name, parents: [dest_parent_id],
            mime_type: GDrive::FOLDER_MIME_TYPE)
          dest_folder = main_wrapper.create_file(dest_folder, fields: "id", supports_all_drives: true)
          map.update!(dest_parent_id: dest_parent_id, dest_id: dest_folder.id)
          dest_folder.id
        end
      end

      def ingest_files
        consent_request.ingest_file_ids.each do |file_id|
          migration_file = File.find_by(external_id: file_id)
          next if migration_file.nil?

          begin
            dest_parent_id = ensure_duplicated_ancestor_tree(migration_file.parent_id)
          rescue FolderMapNotFoundError => error
            migration_file.set_error(type: "folder_map_not_found", message: error.to_s)
            next
          end

          next if dest_parent_id.nil?

          # Move the file to the temp drive by removing the old parent and adding the temp drive.
          # This transfers ownership.
          migration_wrapper.update_file(file_id, add_parents: consent_request.temp_drive_id,
            remove_parents: migration_file.parent_id, supports_all_drives: true)

          # Move the file again to its proper home. The migration_wrapper can't do this because
          # the consenting user may not have permission.
          main_wrapper.update_file(file_id, add_parents: dest_parent_id,
            remove_parents: consent_request.temp_drive_id, supports_all_drives: true)

          migration_file.update!(status: "transferred")
        end
      end
    end
  end
end
