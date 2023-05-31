# frozen_string_literal: true

module GDrive
  class Wrapper
    class RateLimitError < StandardError
    end

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

    def list_files(*args)
      wrap_api_method { service.list_files(*args) }
    end

    def get_file(*args)
      wrap_api_method { service.get_file(*args) }
    end

    def update_file(*args)
      wrap_api_method { service.update_file(*args) }
    end

    def list_drives(*args)
      wrap_api_method { service.list_drives(*args) }
    end

    def list_permissions(*args)
      wrap_api_method { service.list_permissions(*args) }
    end

    def create_permission(*args)
      wrap_api_method { service.create_permission(*args) }
    end

    def update_permission(*args)
      wrap_api_method { service.update_permission(*args) }
    end

    def delete_permission(*args)
      wrap_api_method { service.delete_permission(*args) }
    end

    def has_credentials?
      fetch_credentials_from_store.present?
    end

    def fresh_access_token
      credentials = fetch_credentials_from_store
      credentials.fetch_access_token!
      credentials.access_token
    end

    def fetch_credentials_from_store
      authorizer.get_credentials(google_user_id)
    end

    def revoke_authorization
      authorizer.revoke_authorization(google_user_id)
    end

    def get_credentials_from_code(code:, scope:, base_url:)
      authorizer.get_credentials_from_code(user_id: google_user_id, code: code,
        scope: scope, base_url: base_url)
    end

    def store_credentials(credentials)
      authorizer.store_credentials(google_user_id, credentials)
    end

    def get_authorization_url(request:, state:, redirect_to: nil)
      authorizer.get_authorization_url(login_hint: google_user_id, request: request,
        state: state, redirect_to: redirect_to)
    end

    private

    def wrap_api_method(&block)
      block.call
    rescue Google::Apis::ClientError => error
      # Split rate limit errors into their own class
      new_error =
        if error.message.match?(/rate limit exceeded|too many requests/)
          RateLimitError.new(error.message)
        else
          error
        end
      new_error.set_backtrace(error.backtrace)
      raise new_error
    end

    def service
      return @service if @service
      @service = Google::Apis::DriveV3::DriveService.new
      @service.authorization = fetch_credentials_from_store
      @service
    end

    def authorizer
      return @authorizer if @authorizer
      client_id = Google::Auth::ClientId.new(config.client_id, config.client_secret)
      scope = [
        config.drive_api_scope,
        "https://www.googleapis.com/auth/userinfo.email"
      ]
      token_store = TokenStore.new(config: config)
      @authorizer = Google::Auth::WebUserAuthorizer.new(client_id, scope, token_store, callback_url)
    end
  end
end
