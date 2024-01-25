# frozen_string_literal: true

module GDrive
  module Migration
    # Ingests selected files by moving them to their new homes.
    class IngestJob < BaseJob
      retry_on Google::Apis::ServerError

      attr_accessor :consent_request, :operation, :main_wrapper, :migration_wrapper,
        :ancestor_tree_duplicator

      def perform(cluster_id:, consent_request_id:)
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          self.consent_request = ConsentRequest.find(consent_request_id)
          self.operation = consent_request.operation

          main_config = MainConfig.find_by!(community_id: operation.community_id)
          self.main_wrapper = Wrapper.new(config: main_config, google_user_id: main_config.org_user_id)
          migration_config = consent_request.config
          self.migration_wrapper = Wrapper.new(config: migration_config, google_user_id: @consent_request.google_email)
          self.ancestor_tree_duplicator = AncestorTreeDuplicator.new(wrapper: main_wrapper,
            operation: operation)

          Rails.logger.info("IngestJob starting",
            consent_request_id: consent_request.id,
            file_ids: consent_request.ingest_file_ids,
            operation_id: operation.id)

          ensure_temp_drive
          ingest_files
          files_remaining = File.pending.owned_by(consent_request.google_email).count
          status = files_remaining.zero? ? "done" : "in_progress"
          consent_request.update!(status: status, ingest_status: "done", file_count: files_remaining)
        end
      end

      private

      # This is a separate class method so we can stub it in tests.
      def self.random_request_id
        SecureRandom.uuid
      end

      def ensure_temp_drive
        return if consent_request.temp_drive_id.present?

        temp_drive = Google::Apis::DriveV3::Drive.new(name: "Migration Temp Drive #{consent_request.id}")
        Rails.logger.info("Creating temp drive", name: temp_drive.name)

        # This could only fail if our permissons are bad, which means the whole operation is broken.
        # So we let it bubble up and stop the job.
        temp_drive = main_wrapper.create_drive(self.class.random_request_id, temp_drive)

        # This could only fail if our permissons are bad, which means the whole operation is broken.
        # So we let it bubble up and stop the job.
        Rails.logger.info("Adding temp drive write permission", consenter: consent_request.google_email)
        permission = Google::Apis::DriveV3::Permission.new(type: "user", email_address: consent_request.google_email,
          role: "writer")
        main_wrapper.create_permission(temp_drive.id, permission, supports_all_drives: true, send_notification_email: false)

        consent_request.update!(temp_drive_id: temp_drive.id)
      end

      def ingest_files
        consent_request.ingest_file_ids.each do |file_id|
          Rails.logger.info("Ingesting file", file_id: file_id)
          migration_file = File.find_by(external_id: file_id)

          if migration_file.nil?
            migration_file = build_new_migration_file(file_id)
          end

          begin
            # This could fail if
            # 1. the folder map for migration_file.parent_id is missing or invalid AND
            #   1a. the workspace user doesn't have access to src_folder
            #   1b. the workspace user has access to src_folder but not its parents
            # We need to handle these possibilities and fail gracefully.
            dest_parent_id = ancestor_tree_duplicator.ensure_tree(migration_file.parent_id)
          rescue AncestorTreeDuplicator::ParentFolderInaccessible => error
            Rails.logger.error("Ancestor inaccessible", file_id: file_id, folder_id: error.folder_id)

            # No need to set an error on an unpersisted File, b/c those ones are from files the user
            # picked but we don't have records of, so we are just trying them but they may not be valid.
            if migration_file.persisted?
              migration_file.set_error(type: "ancestor_inaccessible",
                message: "Parent of folder #{error.folder_id}, one of file #{file_id}'s ancestors, is inaccessible")
            end

            next
          rescue Google::Apis::ClientError => error
            Rails.logger.error("Client error ensuring tree", file_id: file_id, message: error.to_s)

            # No need to set an error on an unpersisted File, b/c those ones are from files the user
            # picked but we don't have records of, so we are just trying them but they may not be valid.
            if migration_file.persisted?
              migration_file.set_error(type: "client_error_ensuring_tree", message: error.to_s)
            end

            next
          end

          if dest_parent_id.nil?
            Rails.logger.error("dest_parent_id was nil, aborting", file_id: file_id)
            raise "dest_parent_id should never be nil"
          end

          # Move the file to the temp drive by removing the old parent and adding the temp drive.
          # This transfers ownership.
          # This could only fail if:
          # - The temp drive got deleted, very unlikely.
          # - The file got deleted or moved or permissions changed between when the user
          #   picked it and when the job runs, very unlikely.
          # So we let it bubble up and stop the job.
          Rails.logger.info("Moving file to temp drive.", file_id: file_id)
          migration_wrapper.update_file(file_id, add_parents: consent_request.temp_drive_id,
            remove_parents: migration_file.parent_id, supports_all_drives: true)

          # Move the file again to its proper home. The migration_wrapper can't do this because
          # the consenting user may not have permission.
          # This could fail if:
          # - dest_parent got deleted. This is not likely because AncestorTreeDuplicator should have caught this
          #   and recreated it and updated the folder map, unless dest_parent is the destination root,
          #   which would mean something really weird is going on and we should let the client error bubble up.
          Rails.logger.info("Moving file to final destination.", file_id: file_id, dest_parent_id: dest_parent_id)
          main_wrapper.update_file(file_id, add_parents: dest_parent_id,
            remove_parents: consent_request.temp_drive_id, supports_all_drives: true)

          # This will also save the migration_file if it was an unpersisted one.
          migration_file.update!(status: "transferred")
        end
      end

      # Builds, but does not save, a migration file record based on the given ID.
      # We then proceed through ingestion with this unpersisted object, only saving it if
      # ingestion is successful. Returns nil if getting the file fails or if it's a folder.
      def build_new_migration_file(file_id)
        Rails.logger.info("No matching File record for file. Attempting to create.", file_id: file_id)

        gdrive_file = main_wrapper.get_file(file_id,
          fields: "name,parents,mimeType,webViewLink,iconLink,modifiedTime,owners(emailAddress),capabilities(canEdit)")

        if gdrive_file.parents.blank?
          Rails.logger.error("File has no accessible parents", file_id: file_id)
          return nil
        elsif gdrive_file.mime_type == GDrive::FOLDER_MIME_TYPE
          # This shouldn't normally happen since we don't allow picking folders in the picker
          # but just in case.
          Rails.logger.error("File is a folder, skipping", file_id: file_id)
          return nil
        end

        operation.files.build(
          external_id: file_id,
          name: gdrive_file.name,
          parent_id: gdrive_file.parents[0],
          mime_type: gdrive_file.mime_type,
          owner: gdrive_file.owners[0].email_address,
          status: "pending",
          icon_link: gdrive_file.icon_link,
          web_view_link: gdrive_file.web_view_link,
          modified_at: gdrive_file.modified_time
        )
      rescue Google::Apis::ClientError => error
        Rails.logger.error("Client error looking up file", file_id: file_id, message: error.to_s)
        nil
      end
    end
  end
end
