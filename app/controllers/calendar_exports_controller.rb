class CalendarExportsController < ApplicationController
  prepend_before_action :authenticate_user_from_token!, only: :show
  skip_before_action :ensure_subdomain, only: :show

  def index
    skip_policy_scope
    authorize CalendarExport
    current_user.ensure_calendar_token!
  end

  def show
    authorize CalendarExport
    begin
      data = CalendarExport.new(params[:id].gsub("-", "_"), current_user).generate
      send_data(data, filename: "#{params[:id]}.ics", type: "text/calendar")
    rescue CalendarExport::CalendarTypeError
      render plain: "Invalid calendar type", status: 404
    end
  end

  def reset_token
    authorize CalendarExport
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
    else
      nil
    end
  end
end
