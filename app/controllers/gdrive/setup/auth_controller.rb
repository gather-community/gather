# frozen_string_literal: true

require "googleauth"
require "googleauth/web_user_authorizer"
require "googleauth/stores/redis_token_store"
require "uri"
require "net/http"

module GDrive
  module Setup
    class AuthController < ApplicationController
      USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo"

      # Raised when Google won't tell us which account the new token belongs to.
      class UserinfoError < StandardError
      end

      before_action -> { nav_context(:wiki, :gdrive, :setup, :auth) }

      # We can't use a subdomain on this page due to Google API restrictions.
      prepend_before_action :set_current_community_from_callback_state, only: :callback

      prepend_before_action :stub_g_xsrf_token_in_session if Rails.env.test?

      def callback
        authorize(current_community, :setup?, policy_class: SetupPolicy)

        if params[:error] == "access_denied"
          flash[:error] = t("gdrive.auth_cancelled")
          redirect_to(gdrive_home_url)
          return
        end

        config = Config.find_by!(community: current_community)
        wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id,
          callback_url: gdrive_setup_auth_callback_url(host: Settings.url.host))

        begin
          # If either of these calls error with AuthorizationError,
          # it must be a problem with the client_id/secret
          credentials = fetch_credentials_from_callback_request(wrapper, request)
          authenticated_google_id = fetch_email_of_authenticated_account(credentials)

          if config.org_user_id != authenticated_google_id
            flash[:error] = t("gdrive.wrong_account", signed_in: authenticated_google_id,
              expected: config.org_user_id)
            redirect_to(gdrive_home_url)
            return
          end
          wrapper.store_credentials(credentials)
          flash[:success] = t("gdrive.authenticated")
        rescue Signet::AuthorizationError, UserinfoError => error
          error_code = SecureRandom.base58(8)
          Rails.logger.error("#{error.class.name} in gdrive auth callback", message: error.to_s,
            community_id: current_community.id, error_code: error_code)
          # A bad client ID or secret is the community's to fix, but a failed userinfo request is unexpected.
          if error.is_a?(UserinfoError)
            Gather::ErrorReporter.instance.report(error,
              data: {community_id: current_community.id, error_code: error_code})
          end
          flash[:error] = t("gdrive.connection_problem", code: error_code)
        end
        redirect_to(gdrive_home_url)
      end

      def revoke
        authorize(current_community, :setup?, policy_class: SetupPolicy)
        config = Config.find_by(community: current_community)
        if config
          wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id)
          wrapper.revoke_authorization
        end
        redirect_to(gdrive_home_path)
      end

      private

      def stub_g_xsrf_token_in_session
        request.session["g-xsrf-token"] = ENV["STUB_SESSION_G_XSRF_TOKEN"]
      end

      def set_current_community_from_callback_state
        # Google always sends a JSON state with the community ID. Requests without one come from bots
        # probing the URL. This runs before authentication, so nothing else has turned them away yet.
        community_id = callback_state_community_id
        return render_not_found if community_id.nil?
        @callback_state, = Google::Auth::WebUserAuthorizer.extract_callback_state(request)
        self.current_community = Community.find(community_id)
        # We don't call validate_callback_state here because it will fail if the user has
        # cancelled the oauth request. We check for that in the main callback method body and then
        # we call validate right after. The purpose of this before_action is just to set the current_community.
      end

      def callback_state_community_id
        state = JSON.parse(params[:state].to_s)
        state["community_id"] if state.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end

      def fetch_credentials_from_callback_request(wrapper, request)
        Google::Auth::WebUserAuthorizer.validate_callback_state(@callback_state, request)
        wrapper.get_credentials_from_code(
          code: @callback_state[Google::Auth::WebUserAuthorizer::AUTH_CODE_KEY],
          scope: @callback_state[Google::Auth::WebUserAuthorizer::SCOPE_KEY],
          base_url: request.url
        )
      end

      # Sends the token in a header rather than the URL, so it can't end up in logs along the way.
      def fetch_email_of_authenticated_account(credentials)
        uri = URI(USERINFO_URL)
        auth_header = "Bearer #{credentials.access_token}" # rubocop:disable Gather/HardCodedString -- HTTP auth scheme
        res = Net::HTTP.get_response(uri, {"Authorization" => auth_header})
        raise UserinfoError, "Userinfo request failed with status #{res.code}" unless res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)["email"]
      end
    end
  end
end
