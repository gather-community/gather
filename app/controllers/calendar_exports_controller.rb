class CalendarExportsController < ApplicationController
  prepend_before_action :authenticate_user_from_token!, only: :show

  def index
    skip_policy_scope
    current_user.ensure_calendar_token!
  end

  def show
    skip_authorization
  end
end
