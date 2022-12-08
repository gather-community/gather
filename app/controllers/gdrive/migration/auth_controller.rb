# frozen_string_literal: true

require "googleauth"
require "googleauth/web_user_authorizer"
require "googleauth/stores/redis_token_store"
require "uri"
require "net/http"

module GDrive
  module Migration
    class AuthController < ApplicationController
      USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo?access_token="

      before_action -> { nav_context(:wiki, :gdrive, :migration, :auth) }

      # We can't use a subdomain on these pages due to Google API restrictions.
      prepend_before_action :set_current_community_from_callback_state, only: :callback
      prepend_before_action :set_current_community_from_query_string, except: :callback

      prepend_before_action :stub_g_xsrf_token_in_session if Rails.env.test?

      def index
        skip_policy_scope
        authorize(current_community, policy_class: GDrive::AuthPolicy)
        wrapper = Wrapper.new(community_id: current_community.id, callback_url: callback_url)
        credentials = wrapper.fetch_credentials_from_store
        @config = Config.find_by(community: current_community)
        if @config.nil?
          @no_config = true
          setup_auth_url(wrapper: wrapper)
        elsif @config.folder_id.nil?
          # Ensure we have a fresh token in case the user wants to use the picker.
          credentials.fetch_access_token!
          @no_folder = true
          @access_token = credentials.access_token
        else
          begin
            folder = wrapper.service.get_file(@config.folder_id)
            @folder_name = folder.name
          rescue Google::Apis::ServerError
            flash.now[:error] = "There was a server error when connecting to Google Drive. "\
              "Please try again in a few minutes."
          rescue Google::Apis::AuthorizationError
            setup_auth_url(wrapper: wrapper, config: @config)
            flash.now[:error] = "There was an authorization error when connecting to Google Drive. "\
              "You can try to <a href=\"#{@auth_url}\">Authenticate With Google</a> again.".html_safe
          rescue Google::Apis::ClientError => error
            if error.status_code == 404
              flash.now[:error] = "Your Google Drive folder could not be found. "\
                "You may need to reset your connection."
            else
              raise error
            end
          end
        end
      end

      def callback
        authorize(current_community, policy_class: GDrive::AuthPolicy)

        # @redirect_uri is set in set_current_community_from_callback_state
        # We call it up here since we still want to redirect if the following guard clause is true.
        redirect_to(@redirect_uri)

        if params[:error] == "access_denied"
          flash[:error] = "It looks like you cancelled the Google authentication flow."
          return
        end

        wrapper = Wrapper.new(community_id: current_community.id, callback_url: callback_url)
        credentials = fetch_credentials_from_callback_request(wrapper, request)
        authenticated_google_id = fetch_email_of_authenticated_account(credentials)
        update_config(wrapper, credentials, authenticated_google_id)
      end

      def save_folder
        authorize(current_community, policy_class: GDrive::AuthPolicy)
        Config.find_by!(community: current_community).update!(folder_id: params[:folder_id])
        head(:ok)
      end

      def reset
        authorize(current_community, policy_class: GDrive::AuthPolicy)
        Config.find_by(community: current_community)&.destroy
        redirect_to(gdrive_migration_auth_path(community_id: current_community.id))
      end

      private

      def callback_url
        gdrive_migration_auth_callback_url(host: Settings.url.host)
      end

      def stub_g_xsrf_token_in_session
        request.session["g-xsrf-token"] = ENV["STUB_SESSION_G_XSRF_TOKEN"]
      end

      def set_current_community_from_callback_state
        @callback_state, @redirect_uri = Google::Auth::WebUserAuthorizer.extract_callback_state(request)
        community_id = JSON.parse(params[:state])["community_id"]
        self.current_community = Community.find(community_id)
        # We don't call validate_callback_state here because it will fail if the user has
        # cancelled the oauth request. We check for that in the main callback method body and then
        # we call validate right after. The purpose of this before_action is just to set the current_community.
      end

      def fetch_credentials_from_callback_request(wrapper, request)
        Google::Auth::WebUserAuthorizer.validate_callback_state(@callback_state, request)
        wrapper.authorizer.get_credentials_from_code(
          user_id:  current_community.id,
          code:     @callback_state[Google::Auth::WebUserAuthorizer::AUTH_CODE_KEY],
          scope:    @callback_state[Google::Auth::WebUserAuthorizer::SCOPE_KEY],
          base_url: request.url
        )
      end

      def setup_auth_url(wrapper:, config: nil)
        state = {community_id: current_community.id}
        @auth_url = wrapper.authorizer.get_authorization_url(login_hint: config&.google_id, request: request,
                                                             state: state)
      end

      def fetch_email_of_authenticated_account(credentials)
        uri = URI("#{USERINFO_URL}#{credentials.access_token}")
        res = Net::HTTP.get_response(uri)
        authenticated_google_id = JSON.parse(res.body)["email"]
      end

      def update_config(wrapper, credentials, authenticated_google_id)
        if (config = Config.find_by(community: current_community))
          if config.google_id != authenticated_google_id
            flash[:error] = "You signed into Google with #{authenticated_google_id}. "\
              "Please sign in with #{config.google_id} instead."
            return
          end
        elsif Config.where(google_id: authenticated_google_id).exists?
          flash[:error] = "The Google ID #{authenticated_google_id} is in use by another community."
          return
        else
          Config.create!(community: current_community, google_id: authenticated_google_id)
        end
        wrapper.authorizer.store_credentials(current_community.id, credentials)
      end
    end
  end
end
