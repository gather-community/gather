# frozen_string_literal: true

module GDrive
  module Migration
    # Ingests selected files by moving them to their new homes.
    class IngestJob < BaseJob
      retry_on Google::Apis::ServerError

      attr_accessor :consent_request, :main_wrapper, :migration_wrapper

      def perform(cluster_id:, community_id:, consent_request_id:)
        self.ancestor_tree = {}
        self.ancestor_names = {}
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          self.consent_request = ConsentRequest.find(consent_request_id)
          main_config = MainConfig.find_by!(community_id: community_id)
          self.main_wrapper = Wrapper.new(config: main_config, google_user_id: main_config.org_user_id)
          migration_config = consent_request.config
          self.migration_wrapper = Wrapper.new(config: migration_config, google_user_id: @consent_request.google_email)
          ensure_temp_drive
          ingest_files
        end
      end

      private

      def ensure_temp_drive
        return if consent_request.temp_drive_id.present?

        Rails.logger.info("Creating temp drive '#{temp_drive.name}")
        temp_drive = Google::Apis::DriveV3::Drive.new(name: "Migration Temp Drive #{consent_request.id}")
        temp_drive = main_wrapper.create_drive(SecureRandom.uuid, temp_drive)

        Rails.logger.info("Creating adding write permission for #{consent_request.google_email}")
        permission = Google::Apis::DriveV3::Permission.new(type: "user", email_address: consent_request.google_email,
          role: "writer")
        main_wrapper.create_permission(temp_drive.id, permission, supports_all_drives: true)

        consent_request.update!(temp_drive_id: temp_drive.id)
      end

      def ingest_files
        consent_request.ingest_file_ids.each do |file_id|
          ensure_duplicated_ancestor_tree(file_id)
        end
      end

      # Ensures that the ancestor tree we mapped for the given file also exists
      # in the new drive. Creates it if not.
      def ensure_duplicated_ancestor_tree(file_id)
      end
    end
  end
end
