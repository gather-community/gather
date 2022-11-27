# frozen_string_literal: true

module GDrive
  class Wrapper
    attr_accessor :community_id, :callback_url

    # callback_url is only required if you're planning to call get_authorization_url
    # or get_credentials_from_code on the WebUserAuthorizer object.
    def initialize(community_id:, callback_url: nil)
      self.community_id = community_id
      self.callback_url = callback_url
    end

    def service
      return @service if @service
      @service = Google::Apis::DriveV3::DriveService.new
      @service.authorization = fetch_credentials_from_store
      @service
    end

    def fresh_access_token
      credentials = fetch_credentials_from_store
      credentials.fetch_access_token!
      credentials.access_token
    end

    def fetch_credentials_from_store
      authorizer.get_credentials(community_id.to_s)
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
      @authorizer = Google::Auth::WebUserAuthorizer.new(client_id, scope, token_store, callback_url)
    end
  end
end
