class AccountsController < ApplicationController
  load_and_authorize_resource

  def index
    @accounts = @accounts.joins(:household).
      includes(:last_invoice, household: :community).
      for_community(current_user.community).
      where("households.deactivated_at IS NULL OR current_balance >= 0.01").
      by_household_full_name.
      page(params[:page]).per(20)

    @grand_total_due = Account.for_community(current_user.community).sum("current_balance")
    @nonzero_accounts = Account.for_community(current_user.community).where("current_balance >= 0.01").count
  end
end
