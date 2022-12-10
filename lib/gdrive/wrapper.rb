# frozen_string_literal: true

module GDrive
  class Wrapper
    attr_accessor :config, :callback_url

    # callback_url is only required if you're planning to call get_authorization_url
    # or get_credentials_from_code on the WebUserAuthorizer object.
    def initialize(config:, callback_url: nil)
      raise ArgumentError, "config cannot be nil" if config.nil?
      self.config = config
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
      authorizer.get_credentials(config.community_id.to_s)
    end

    def authorizer
      return @authorizer if @authorizer
      auth_settings = Settings.gdrive.auth
      client_id = Google::Auth::ClientId.new(config.client_id, config.client_secret)
      scope = [
        "https://www.googleapis.com/auth/drive",
        "https://www.googleapis.com/auth/userinfo.email"
      ]
      token_store = TokenStore.new
      @authorizer = Google::Auth::WebUserAuthorizer.new(client_id, scope, token_store, callback_url)
    end
  end
end
