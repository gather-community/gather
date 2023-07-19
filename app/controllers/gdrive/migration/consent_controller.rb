# frozen_string_literal: true

module GDrive
  module Migration
    class ConsentController < ApplicationController
      USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo?access_token="

      # These are public pages. Authentication comes from the token in the query string.
      skip_before_action :authenticate_user!
      skip_after_action :verify_authorized

      # We can't use a subdomain on these pages due to Google API restrictions.
      prepend_before_action :set_current_community_from_callback_state, only: :callback
      prepend_before_action :set_current_community_from_query_string, except: :callback

      # This will get pulled from a model later.
      TEMP_USER_ID = "example@gmail.com"

      def intro
        @config = MigrationConfig.find_by(community: current_community)

        if @config.nil?
          @no_config = true
          return
        end

        wrapper = Wrapper.new(config: @config, google_user_id: TEMP_USER_ID, callback_url: callback_url)
        credentials = wrapper.fetch_credentials_from_store

        if wrapper.has_credentials?
          # Ensure we have a fresh token for the picker.
          credentials.fetch_access_token!
        else
          @no_credentials = true
          setup_auth_url(wrapper: wrapper)
        end
      end

      def step1
        @config = MigrationConfig.find_by(community: current_community)

        if @config.nil?
          @no_config = true
          return
        end

        wrapper = Wrapper.new(config: @config, google_user_id: TEMP_USER_ID, callback_url: callback_url)

        if wrapper.has_credentials?
          redirect_to(gdrive_migration_consent_step2_url(host: Settings.url.host, community_id: current_community.id))
        else
          setup_auth_url(wrapper: wrapper)
        end
      end

      def callback
        if params[:error] == "access_denied"
          flash[:error] = "It looks like you cancelled the Google authentication flow."
          redirect_to(gdrive_migration_consent_step1_url(host: Settings.url.host, community_id: current_community.id))
          return
        end

        config = MigrationConfig.find_by!(community: current_community)
        wrapper = Wrapper.new(config: config, google_user_id: TEMP_USER_ID, callback_url: callback_url)
        credentials = fetch_credentials_from_callback_request(wrapper, request)
        authenticated_google_id = fetch_email_of_authenticated_account(credentials)
        if TEMP_USER_ID != authenticated_google_id
          flash[:error] = "You signed into Google with #{authenticated_google_id}. " \
            "Please sign in with #{config.org_user_id} instead."
          redirect_to(gdrive_migration_consent_step1_url(host: Settings.url.host, community_id: current_community.id))
          return
        end
        wrapper.store_credentials(credentials)
        redirect_to(gdrive_migration_consent_step2_url(host: Settings.url.host, community_id: current_community.id))
      end

      def step2
        @config = MigrationConfig.find_by(community: current_community)

        if @config.nil?
          @no_config = true
          return
        end

        wrapper = Wrapper.new(config: @config, google_user_id: TEMP_USER_ID, callback_url: callback_url)

        if !wrapper.has_credentials?
          redirect_to(gdrive_migration_consent_step1_url(host: Settings.url.host, community_id: current_community.id))
        else
          credentials = wrapper.fetch_credentials_from_store
          credentials.fetch_access_token!
          @access_token = credentials.access_token
        end
      end

      private

      def callback_url
        gdrive_migration_consent_callback_url(host: Settings.url.host)
      end

      def set_current_community_from_callback_state
        @callback_state, = Google::Auth::WebUserAuthorizer.extract_callback_state(request)
        community_id = JSON.parse(params[:state])["community_id"]
        self.current_community = Community.find(community_id)
        # We don't call validate_callback_state here because it will fail if the user has
        # cancelled the oauth request. We check for that in the main callback method body and then
        # we call validate right after. The purpose of this before_action is just to set the current_community.
      end

      def fetch_credentials_from_callback_request(wrapper, request)
        Google::Auth::WebUserAuthorizer.validate_callback_state(@callback_state, request)
        wrapper.get_credentials_from_code(
          code: @callback_state[Google::Auth::WebUserAuthorizer::AUTH_CODE_KEY],
          scope: @callback_state[Google::Auth::WebUserAuthorizer::SCOPE_KEY],
          base_url: request.url
        )
      end

      def setup_auth_url(wrapper:, config: nil)
        state = {community_id: current_community.id}
        @auth_url = wrapper.get_authorization_url(request: request, state: state)
      end

      def fetch_email_of_authenticated_account(credentials)
        uri = URI("#{USERINFO_URL}#{credentials.access_token}")
        res = Net::HTTP.get_response(uri)
        JSON.parse(res.body)["email"]
      end
    end
  end
end
