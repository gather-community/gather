class CalendarExportsController < ApplicationController
  def index
    skip_policy_scope
    current_user.ensure_calendar_token!
  end
end
