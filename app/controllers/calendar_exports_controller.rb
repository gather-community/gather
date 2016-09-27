class CalendarExportsController < ApplicationController
  prepend_before_action :authenticate_user_from_token!, only: :show

  def index
    skip_policy_scope
    current_user.ensure_calendar_token!
  end

  def show
    skip_authorization
    data = CalendarExporter.new(params[:id].gsub("-", "_"), current_user).generate
    send_data(data, filename: "#{params[:id]}.ics", type: "text/calendar")
  end
end
