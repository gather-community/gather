# frozen_string_literal: true

require "googleauth"
require "googleauth/web_user_authorizer"
require "googleauth/stores/redis_token_store"
require "uri"
require "net/http"

module GDrive
  class AuthController < ApplicationController
    USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo?access_token="

    prepend_before_action :set_current_community_from_query_string, only: :index
    prepend_before_action :set_current_community_from_callback_state, only: :callback

    def index
      skip_policy_scope
      authorize(current_community, policy_class: GDrive::AuthPolicy)
      credentials = authorizer.get_credentials(current_community.id.to_s)
      config = Config.find_by(community: current_community)
      if credentials.nil?
        state = {community_id: current_community.id}
        @auth_url = authorizer.get_authorization_url(login_hint: "tscohotech@gmail.com", request: request,
                                                     state: state, redirect_to: gdrive_pick_folder_url)
      elsif config.folder_id.nil?
        # Ensure we have a fresh token in case the user wants to use the picker.
        credentials.fetch_access_token!
        @no_folder = true
        @access_token = credentials.access_token
      else
        begin
          drive = Google::Apis::DriveV3::DriveService.new
          drive.authorization = credentials
          folder = drive.get_file(config.folder_id)
          @folder_name = folder.name
        rescue Google::Apis::ServerError
          @error = "server error"
        rescue Google::Apis::AuthorizationError
          @error = "unauthorized"
        rescue Google::Apis::ClientError => error
          if error.status_code == 404
            @error = "not found"
          else
            raise error
          end
        end
      end
    end

    def callback
      authorize(current_community, policy_class: GDrive::AuthPolicy)

      credentials = authorizer.get_credentials_from_code(
        user_id:  current_community.id,
        code:     @callback_state[Google::Auth::WebUserAuthorizer::AUTH_CODE_KEY],
        scope:    @callback_state[Google::Auth::WebUserAuthorizer::SCOPE_KEY],
        base_url: request.url
      )

      uri = URI("#{USERINFO_URL}#{credentials.access_token}")
      res = Net::HTTP.get_response(uri)
      google_id = JSON.parse(res.body)["email"]
      Config.create!(community: current_community, google_id: google_id)
      # ERROR HANDLING

      @authorizer.store_credentials(current_community.id, credentials)

      redirect_to(@redirect_uri)
    end

    def save_folder
      authorize(current_community, policy_class: GDrive::AuthPolicy)
      Config.find_by!(community: current_community).update!(folder_id: params[:folder_id])
      redirect_to(gdrive_auth_url(subdomain: nil, community_id: current_community.id))
    end

    private

    def set_current_community_from_query_string
      self.current_community = Community.find(params[:community_id])
    end

    def set_current_community_from_callback_state
      @callback_state, @redirect_uri = Google::Auth::WebUserAuthorizer.extract_callback_state(request)
      community_id = JSON.parse(params[:state])["community_id"]
      Google::Auth::WebUserAuthorizer.validate_callback_state(@callback_state, request)
      self.current_community = Community.find(community_id)
    end

    def authorizer
      return @authorizer if @authorizer
      auth_settings = Settings.gdrive.auth
      client_id = Google::Auth::ClientId.new(auth_settings.client_id, auth_settings.client_secret)
      scope = ["https://www.googleapis.com/auth/drive.file"]
      token_store = TokenStore.new
      redirect_url = gdrive_auth_callback_url(host: Settings.url.host, port: Settings.url.port)
      @authorizer = Google::Auth::WebUserAuthorizer.new(client_id, scope, token_store, redirect_url)
    end
  end
end
