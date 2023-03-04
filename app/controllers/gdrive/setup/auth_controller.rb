# frozen_string_literal: true

require "googleauth"
require "googleauth/web_user_authorizer"
require "googleauth/stores/redis_token_store"
require "uri"
require "net/http"

module GDrive
  module Setup
    class AuthController < ApplicationController
      USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo?access_token="

      before_action -> { nav_context(:wiki, :gdrive, :setup, :auth) }

      # We can't use a subdomain on these pages due to Google API restrictions.
      prepend_before_action :set_current_community_from_callback_state, only: :callback
      prepend_before_action :set_current_community_from_query_string, except: :callback

      prepend_before_action :stub_g_xsrf_token_in_session if Rails.env.test?

      def index
        skip_policy_scope
        authorize(current_community, :setup?, policy_class: SetupPolicy)
        @config = MainConfig.find_by(community: current_community)
        return if @config.nil?

        wrapper = Wrapper.new(config: @config, google_user_id: @config.org_user_id,
                              callback_url: callback_url)
        credentials = wrapper.fetch_credentials_from_store

        if credentials.nil?
          @no_auth = true
          setup_auth_url(wrapper: wrapper)
        end
      end

      def callback
        authorize(current_community, :setup?, policy_class: SetupPolicy)

        # @redirect_uri is set in set_current_community_from_callback_state
        # We call it up here since we still want to redirect if the following guard clause is true.
        redirect_to(@redirect_uri)

        if params[:error] == "access_denied"
          flash[:error] = "It looks like you cancelled the Google authentication flow."
          return
        end

        config = MainConfig.find_by!(community: current_community)
        wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id, callback_url: callback_url)
        credentials = fetch_credentials_from_callback_request(wrapper, request)
        authenticated_google_id = fetch_email_of_authenticated_account(credentials)
        if config.org_user_id != authenticated_google_id
          flash[:error] = "You signed into Google with #{authenticated_google_id}. "\
            "Please sign in with #{config.org_user_id} instead."
          return
        end
        wrapper.store_credentials(credentials)
      end

      private

      def callback_url
        gdrive_setup_auth_callback_url(host: Settings.url.host)
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
        authenticated_google_id = JSON.parse(res.body)["email"]
      end
    end
  end
end