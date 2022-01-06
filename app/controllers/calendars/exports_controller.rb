# frozen_string_literal: true

module Calendars
  # Calendar exports
  class ExportsController < ApplicationController
    include Exportable

    # Authentication happens via token and community calendars aren't user-authenticated.
    skip_before_action :authenticate_user!, only: :community

    def index
      skip_policy_scope
      authorize(current_community, policy_class: ExportPolicy)
      current_user.ensure_calendar_token!
    end

    def reset_token
      authorize(current_community, policy_class: ExportPolicy)
      current_user.reset_calendar_token!
      flash[:success] = "Token reset successfully."
      redirect_to(calendars_exports_path)
    end
  end
end
