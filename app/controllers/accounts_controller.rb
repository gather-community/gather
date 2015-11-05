class AccountsController < ApplicationController
  load_and_authorize_resource

  def index
    @accounts = @accounts.joins(:household).
      includes(:last_statement, household: :community).
      for_community(current_user.community).
      where("households.deactivated_at IS NULL OR current_balance >= 0.01").
      by_household_full_name.
      page(params[:page]).per(20)

    @active_accounts = Account.for_community(current_user.community).with_recent_activity.count

    last_statement = Statement.for_community(current_user.community).order(:created_at).last
    @last_statement_run = last_statement.try(:created_on)
  end
end
