# frozen_string_literal: true

module GDrive
  module Migration
    # Ingests selected files by moving them to their new homes.
    class IngestJob < BaseJob
      retry_on Google::Apis::ServerError

      attr_accessor :consent_request, :operation, :main_wrapper, :migration_wrapper,
        :ancestor_tree_duplicator

      def perform(cluster_id:, community_id:, consent_request_id:)
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          self.consent_request = ConsentRequest.find(consent_request_id)
          self.operation = consent_request.operation
          main_config = MainConfig.find_by!(community_id: community_id)
          self.main_wrapper = Wrapper.new(config: main_config, google_user_id: main_config.org_user_id)
          migration_config = consent_request.config
          self.migration_wrapper = Wrapper.new(config: migration_config, google_user_id: @consent_request.google_email)
          self.ancestor_tree_duplicator = AncestorTreeDuplicator.new(wrapper: main_wrapper, operation: operation)
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
        Rails.logger.info("Creating temp drive '#{temp_drive.name}")

        # This could only fail if our permissons are bad, which means the whole operation is broken.
        # So we let it bubble up and stop the job.
        temp_drive = main_wrapper.create_drive(self.class.random_request_id, temp_drive)

        # This could only fail if our permissons are bad, which means the whole operation is broken.
        # So we let it bubble up and stop the job.
        Rails.logger.info("Adding temp drive write permission for #{consent_request.google_email}")
        permission = Google::Apis::DriveV3::Permission.new(type: "user", email_address: consent_request.google_email,
          role: "writer")
        main_wrapper.create_permission(temp_drive.id, permission, supports_all_drives: true, send_notification_email: false)

        consent_request.update!(temp_drive_id: temp_drive.id)
      end

      def ingest_files
        consent_request.ingest_file_ids.each do |file_id|
          migration_file = File.find_by(external_id: file_id)
          next if migration_file.nil?

          begin
            # This could fail if
            # 1. the folder map for migration_file.parent_id is missing or invalid AND
            #   1a. the workspace user doesn't have access to src_folder
            #   1b. the workspace user has access to src_folder but not its parents
            # We need to handle these possibilities and fail gracefully.
            dest_parent_id = ancestor_tree_duplicator.ensure_tree(migration_file.parent_id)
          rescue AncestorTreeDuplicator::ParentFolderInaccessible => error
            migration_file.set_error(type: "ancestor_inaccessible", message: "Parent of folder #{error.folder_id}, one of file #{file_id}'s ancestors, is inaccessible")
            next
          rescue Google::Apis::ClientError => error
            migration_file.set_error(type: "client_error_ensuring_tree", message: error.to_s)
            next
          end

          raise "dest_parent_id should never be nil" if dest_parent_id.nil?

          # Move the file to the temp drive by removing the old parent and adding the temp drive.
          # This transfers ownership.
          # This could only fail if:
          # - The temp drive got deleted, very unlikely.
          # - The file got deleted or moved or permissions changed between when the user
          #   picked it and when the job runs, very unlikely.
          # So we let it bubble up and stop the job.
          migration_wrapper.update_file(file_id, add_parents: consent_request.temp_drive_id,
            remove_parents: migration_file.parent_id, supports_all_drives: true)

          # Move the file again to its proper home. The migration_wrapper can't do this because
          # the consenting user may not have permission.
          # This could fail if:
          # - dest_parent got deleted. This is not likely because AncestorTreeDuplicator should have caught this
          #   and recreated it and updated the folder map, unless dest_parent is the destination root,
          #   which would mean something really weird is going on and we should let the client error bubble up.
          main_wrapper.update_file(file_id, add_parents: dest_parent_id,
            remove_parents: consent_request.temp_drive_id, supports_all_drives: true)

          migration_file.update!(status: "transferred")
        end
      end
    end
  end
end
