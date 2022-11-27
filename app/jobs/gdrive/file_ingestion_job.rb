# frozen_string_literal: true

module GDrive
  # Ingests selected files by starring them and noting any unowned files.
  class FileIngestionJob < ApplicationJob
    attr_accessor :batch

    delegate :gdrive_config, to: :batch
    delegate :community_id, to: :gdrive_config

    def perform(cluster_id:, batch_id:)
      ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
        self.batch = FileIngestionBatch.find(batch_id)
        batch.picked["docs"].each do |doc|
          ingest_file(doc["id"])
        end
        star_any_unstarred_files
      end
    end

    private

    def ingest_file(file_id)
      # This request may fail if the selected object was a shortcut and the user hadn't already picked
      # the target file. So we should handle that gracefully.
      # It could also lead to a duplicate insertion in the UnownedFile table if the target file HAS already
      # been picked. So we need to handle that gracefully too.
      Rails.logger.info("[GDrive] Marking file #{file_id} as starred")
      begin
        file = drive_service.update_file(
          file_id,
          Google::Apis::DriveV3::File.new(starred: true),
          fields: "id,name,mimeType,owners(emailAddress),shortcutDetails(targetId,targetMimeType)"
        )
      rescue => error
        ErrorReporter.instance.report(error, data: {file_id: file_id})
        Rails.logger.error("[GDrive] Error #{error.inspect} marking file #{file_id} as starred")
      end
      log_shortcut_details(file)
      record_file_if_unowned(file)
    end

    def log_shortcut_details(file)
      return if file.shortcut_details.nil?
      Rails.logger.info("[GDrive] File #{file.id} has shortcut details: #{file.shortcut_details}")
    end

    def record_file_if_unowned(file)
      return if file.owners.any? { |o| o.email_address == gdrive_config.google_id }
      owners = file.owners.map(&:email_address).join(",")
      Rails.logger.info("[GDrive] File #{file.id} is owned by #{owners}, saving record")
      unowned_file = UnownedFile.create_with(
        owner: owners,
        data: {name: file.name, mime_type: file.mime_type, shortcut_details: file.shortcut_details}
      ).find_or_create_by!(
        gdrive_config: gdrive_config,
        external_id: file.id
      )
      unless unowned_file.id_previously_changed?
        Rails.logger.info("[GDrive] File #{file.id} already had UnownedFile record")
      end
    end

    # If the user selects a shortcut, the ID of the linked-to file will be sent to this job, not
    # this ID of the shortcut. We will try to star the linked-to file (it may already have a star
    # if it was already selected, or it may not). The shortcut will remain unstarred, even though we will
    # have access to it. So each time we run this job, we check for any unstarred files that we
    # have access to and ingest them. Otherwise, the shortcuts will keep appearing in the picker.
    def star_any_unstarred_files
      page_token = nil
      loop do
        result = drive_service.list_files(q: "starred = false", page_size: 1000, page_token: page_token)
        if result.files.any?
          Rails.logger.info("[GDrive] Ingesting #{result.files.size} unstarred but accessible files")
          result.files.each do |file|
            Rails.logger.info("[GDrive] File #{file.id} is accessible but not starred, ingesting")
            ingest_file(file.id)
          end
        end
        break if result.next_page_token.nil?
        page_token = result.next_page_token
      end
    end

    def drive_service
      return @drive_service if @drive_service

      auth_settings = Settings.gdrive.auth
      client_id = Google::Auth::ClientId.new(auth_settings.client_id, auth_settings.client_secret)
      scope = [
        "https://www.googleapis.com/auth/drive.file",
        "https://www.googleapis.com/auth/userinfo.email"
      ]
      token_store = GDrive::TokenStore.new
      authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
      credentials = authorizer.get_credentials(community_id)

      raise Google::Apis::AuthorizationError, "No valid credentials stored" if credentials.nil?

      @drive_service = Google::Apis::DriveV3::DriveService.new
      @drive_service.authorization = credentials
      @drive_service
    end
  end
end
