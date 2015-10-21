class AccountsController < ApplicationController
  authorize_resource

  def index
    households = Household.in_community(current_user.community).by_active_and_name
    @accounts = Account.for_households(households)
  end
end
