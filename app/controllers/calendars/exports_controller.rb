# frozen_string_literal: true

module Calendars
  # Calendar exports
  class ExportsController < ApplicationController
    # Users are authenticated from the provided token for the personalized endpoint.
    prepend_before_action :authenticate_user_from_token!, only: :personalized

    # This is skipped to support legacy domains.
    skip_before_action :ensure_subdomain, only: :personalized

    # Community calendars are not user-specific. Authorization is handled by the policy class
    # based on the community calendar token.
    skip_before_action :authenticate_user!, only: :community

    def index
      skip_policy_scope
      authorize(sample_export, policy_class: ExportPolicy)
      current_user.ensure_calendar_token!
    end

    def community
      export = Exports::Factory.build(type: params[:id], community: current_community)
      policy = ExportPolicy.new(nil, export, community_token: params[:calendar_token])
      authorize_with_explict_policy_object(export, :community?, policy_object: policy)
      send_calendar_data(export)
    rescue Exports::TypeError
      handle_calendar_error
    end

    def personalized
      export = Exports::Factory.build(type: params[:id], user: current_user)
      authorize(export, policy_class: ExportPolicy)
      send_calendar_data(export)
    rescue Exports::TypeError
      handle_calendar_error
    end

    def reset_token
      authorize(sample_export, policy_class: ExportPolicy)
      current_user.reset_calendar_token!
      flash[:success] = "Token reset successfully."
      redirect_to(calendar_exports_path)
    end

    protected

    # See def'n in ApplicationController for documentation.
    def community_for_route
      case params[:action]
      when "index", "personalized"
        current_user.community
      end
    end

    private

    def sample_export
      Exports::Export.new(user: current_user)
    end

    def send_calendar_data(export)
      send_data(export.generate, filename: "#{params[:id]}.ics", type: "text/calendar")
    end

    def handle_calendar_error
      skip_authorization # Auth may not have been performed yet but that's OK b/c we're erroring.
      render(plain: "Invalid calendar type", status: :not_found)
    end
  end
end
