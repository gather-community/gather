class UsersController < ApplicationController
  load_and_authorize_resource

  def update
    if @user.update_attributes(user_params)
      redirect_to root_path
    else
      render :edit
    end
  end

  private

  def user_params
    permitted = [:email, :first_name, :last_name, :mobile_phone, :home_phone, :work_phone]
    permitted += [:admin, :google_email, :household_id] if can?(:manage, @user)
    params.require(:user).permit(permitted)
  end
end
