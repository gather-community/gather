# frozen_string_literal: true

module Calendars
  # Calendar exports
  class ExportsController < ApplicationController
    prepend_before_action :authenticate_user_from_token!, only: :show
    skip_before_action :ensure_subdomain, only: :show

    def index
      skip_policy_scope
      authorize(sample_export, policy_class: ExportPolicy)
      current_user.ensure_calendar_token!
    end

    def show
      authorize(sample_export, policy_class: ExportPolicy)
      begin
        data = Exports::Factory.build(type: params[:id], user: current_user).generate
        send_data(data, filename: "#{params[:id]}.ics", type: "text/calendar")
      rescue Exports::TypeError
        render(plain: "Invalid calendar type", status: :not_found)
      end
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
      when "index", "show"
        current_user.community
      end
    end

    private

    def sample_export
      Exports::Export.new(user: current_user)
    end
  end
end
