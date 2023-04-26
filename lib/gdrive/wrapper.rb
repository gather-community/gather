# frozen_string_literal: true

module GDrive
  class Wrapper
    attr_accessor :config, :google_user_id, :callback_url

    # callback_url is only required if you're planning to call get_authorization_url
    # or get_credentials_from_code on the WebUserAuthorizer object.
    def initialize(config:, google_user_id:, callback_url: nil)
      raise ArgumentError, "config cannot be nil" if config.nil?
      raise ArgumentError, "google_user_id cannot be nil" if google_user_id.nil?
      self.config = config
      self.google_user_id = google_user_id
      self.callback_url = callback_url
    end

    def has_credentials?
      fetch_credentials_from_store.present?
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
      authorizer.get_credentials(google_user_id)
    end

    def get_credentials_from_code(code:, scope:, base_url:)
      authorizer.get_credentials_from_code(user_id: google_user_id, code: code,
                                           scope: scope, base_url: base_url)
    end

    def store_credentials(credentials)
      authorizer.store_credentials(google_user_id, credentials)
    end

    def get_authorization_url(request:, state:)
      authorizer.get_authorization_url(login_hint: google_user_id, request: request, state: state)
    end

    private

    def authorizer
      return @authorizer if @authorizer
      client_id = Google::Auth::ClientId.new(config.client_id, config.client_secret)
      scope = [
        "https://www.googleapis.com/auth/drive",
        "https://www.googleapis.com/auth/userinfo.email"
      ]
      token_store = TokenStore.new(config: config)
      @authorizer = Google::Auth::WebUserAuthorizer.new(client_id, scope, token_store, callback_url)
    end
  end
end
