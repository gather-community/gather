# frozen_string_literal: true

module GDrive
  module Migration
    class ConsentController < ApplicationController
      USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo?access_token="

      # These are public pages. Authentication comes from the token in the query string.
      skip_before_action :authenticate_user!
      skip_after_action :verify_authorized

      # For signed-in pages, we redirect to the appropriate community.
      # Here we should 404 if no community, except for the callback endpoint
      before_action :ensure_community

      # We can't use a subdomain on these pages due to Google API restrictions.
      prepend_before_action :set_current_community_from_callback_state, only: :callback

      before_action :load_and_check_consent_request, except: %i[callback ingest_status opt_out_complete]

      def intro
        @operation = @consent_request.operation
        @config = @operation.config
        @community = current_community
      end

      def auth
        @operation = @consent_request.operation
        @config = @operation.config
        @community = current_community

        wrapper = Wrapper.new(config: @config, google_user_id: @consent_request.google_email,
                              callback_url: callback_url)

        if wrapper.has_credentials?
          redirect_to(gdrive_migration_consent_pick_url)
        else
          setup_auth_url(wrapper: wrapper, consent_request_token: @consent_request.token)
        end
      end

      def callback
        state = JSON.parse(params["state"]).symbolize_keys
        consent_request = ConsentRequest.find_by!(token: state[:consent_request_token])

        if params[:error] == "access_denied"
          flash[:error] = "It looks like you cancelled the Google authentication flow."
          redirect_to(gdrive_migration_consent_auth_url(token: consent_request.token))
          return
        end

        operation = consent_request.operation
        config = operation.config
        wrapper = Wrapper.new(config: config, google_user_id: consent_request.google_email,
                              callback_url: callback_url)
        credentials = fetch_credentials_from_callback_request(wrapper, request)
        authenticated_google_id = fetch_email_of_authenticated_account(credentials)

        if consent_request.google_email != authenticated_google_id
          flash[:error] = "You signed into Google with #{authenticated_google_id}. " \
                          "Please sign in with #{consent_request.google_email} instead."
          redirect_to(gdrive_migration_consent_auth_url(token: consent_request.token))
          return
        end

        wrapper.store_credentials(credentials)
        redirect_to(gdrive_migration_consent_pick_url(token: consent_request.token))
      end

      def pick
        operation = @consent_request.operation
        @migration_config = operation.config
        main_config = MainConfig.find_by!(community: current_community)
        @org_user_id = main_config.org_user_id
        @community = current_community
        wrapper = Wrapper.new(config: @migration_config, google_user_id: @consent_request.google_email,
                              callback_url: callback_url)

        if wrapper.has_credentials?
          # Fetch a fresh access token for the picker.
          credentials = wrapper.fetch_credentials_from_store
          credentials.fetch_access_token!
          @access_token = credentials.access_token

          @consent_request.update!(status: "in_progress")
        else
          redirect_to(gdrive_migration_consent_auth_url)
        end
      end

      def ingest
        @consent_request.setup_ingest(params[:file_ids])
        IngestJob.perform_later(
          cluster_id: current_cluster.id,
          consent_request_id: @consent_request.id
        )
        head(:no_content)
      end

      def ingest_status
        @consent_request = ConsentRequest.find_by!(token: params[:token])
        main_config = MainConfig.find_by!(community: current_community)
        org_user_id = main_config.org_user_id

        if @consent_request.ingest_overdue?
          Gather::ErrorReporter.instance.report(StandardError.new("GDrive file ingest overdue"),
                                                data: {consent_request_id: @consent_request.id})
          @consent_request.set_ingest_failed
        end

        result = {
          status: @consent_request.ingest_status,
          progress: @consent_request.ingest_progress,
          total: @consent_request.ingest_file_ids.size
        }
        if @consent_request.ingest_done? || @consent_request.ingest_failed?
          result[:instructions] = render_to_string(partial: "instructions",
                                                   locals: {consent_request: @consent_request, community: current_community,
                                                            org_user_id: org_user_id})
        end

        render(json: result)
      end

      def opt_out
        @uningested_files = @consent_request.operation.files.where(owner: @consent_request.google_email,
                                                                   status: "pending")
          .order(:name).page(params[:page])
      end

      def confirm_opt_out
        @consent_request.update!(status: "opted_out",
                                 opt_out_reason: params[:gdrive_migration_consent_request][:opt_out_reason])
        @consent_request.operation.files.where(owner: @consent_request.google_email,
                                               status: "pending").update_all(status: "declined")
        redirect_to(gdrive_migration_consent_opt_out_complete_path)
      end

      def opt_out_complete
      end

      private

      def load_and_check_consent_request
        @consent_request = ConsentRequest.find_by!(token: params[:token])
        render_not_found unless @consent_request.pending?
      end

      def callback_url
        gdrive_migration_consent_callback_url(host: Settings.url.host)
      end

      def ensure_community
        render_not_found unless current_community
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

      def setup_auth_url(wrapper:, consent_request_token:, config: nil)
        state = {community_id: current_community.id, consent_request_token: consent_request_token}
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
