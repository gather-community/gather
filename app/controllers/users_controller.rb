class UsersController < ApplicationController
  load_and_authorize_resource

  def index
    @users = User.by_active_and_name
  end

  def update
    if @user.update_attributes(user_params)
      flash[:success] = "User updated successfully."
      redirect_to root_path
    else
      render :edit
    end
  end

  def destroy
    @user.soft_delete!
    flash[:success] = "User deactivated successfully."
    redirect_to(users_path)
  end

  def undelete
    @user.undelete!
    redirect_to(users_path)
  end

  private

  def user_params
    permitted = [:email, :first_name, :last_name, :mobile_phone, :home_phone, :work_phone]
    permitted += [:admin, :google_email, :household_id] if can?(:manage, @user)
    params.require(:user).permit(permitted)
  end
end
