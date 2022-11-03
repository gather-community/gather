# frozen_string_literal: true

module GDrive
  # Methods common to controllers that talk to Google Drive.
  module GDriveable
    extend ActiveSupport::Concern

    def drive_service
      return @drive_service if @drive_service
      @drive_service = Google::Apis::DriveV3::DriveService.new
      @drive_service.authorization = fetch_credentials_from_store
      @drive_service
    end

    def fetch_credentials_from_store
      authorizer.get_credentials(current_community.id.to_s)
    end

    def authorizer
      return @authorizer if @authorizer
      auth_settings = Settings.gdrive.auth
      client_id = Google::Auth::ClientId.new(auth_settings.client_id, auth_settings.client_secret)
      scope = [
        "https://www.googleapis.com/auth/drive.file",
        "https://www.googleapis.com/auth/userinfo.email"
      ]
      token_store = TokenStore.new
      redirect_url = gdrive_auth_callback_url(host: Settings.url.host)
      @authorizer = Google::Auth::WebUserAuthorizer.new(client_id, scope, token_store, redirect_url)
    end
  end
end
