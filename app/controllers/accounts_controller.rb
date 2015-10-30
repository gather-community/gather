class AccountsController < ApplicationController
  authorize_resource

  def index
    @households = Household.joins(:account).includes(:account).in_community(current_user.community).
      where("deactivated_at IS NULL OR
        COALESCE(accounts.due_last_invoice,0) - total_new_credits + total_new_charges > 0.01").
      by_name.page(params[:page]).per(20)
  end
end
