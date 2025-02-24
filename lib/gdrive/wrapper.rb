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

    def batch(...)
      wrap_api_method { service.batch(...) }
    end

    def list_files(...)
      wrap_api_method { service.list_files(...) }
    end

    def get_file(...)
      wrap_api_method { service.get_file(...) }
    end

    def create_file(...)
      wrap_api_method { service.create_file(...) }
    end

    def update_file(...)
      wrap_api_method { service.update_file(...) }
    end

    def list_drives(...)
      wrap_api_method { service.list_drives(...) }
    end

    def create_drive(...)
      wrap_api_method { service.create_drive(...) }
    end

    def delete_drive(...)
      wrap_api_method { service.delete_drive(...) }
    end

    def list_permissions(...)
      wrap_api_method { service.list_permissions(...) }
    end

    def create_permission(...)
      wrap_api_method { service.create_permission(...) }
    end

    def update_permission(...)
      wrap_api_method { service.update_permission(...) }
    end

    def delete_permission(...)
      wrap_api_method { service.delete_permission(...) }
    end

    def get_changes_start_page_token(...)
      wrap_api_method { service.get_changes_start_page_token(...) }
    end

    def watch_change(...)
      wrap_api_method { service.watch_change(...) }
    end

    def stop_channel(...)
      wrap_api_method { service.stop_channel(...) }
    end

    def list_changes(...)
      wrap_api_method { service.list_changes(...) }
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
    rescue Google::Apis::ClientError => e
      # Split rate limit errors into their own class
      new_error =
        if e.message.match?(/rate limit exceeded|too many requests/)
          RateLimitError.new(e.message)
        else
          e
        end
      new_error.set_backtrace(e.backtrace)
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
