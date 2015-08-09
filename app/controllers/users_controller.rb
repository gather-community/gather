class UsersController < ApplicationController
  load_and_authorize_resource

  def index
    @users = User.by_active_and_name
  end

  def new
    @user = User.new
  end

  def create
    if @user.save
      flash[:success] = "User created successfully."
      redirect_to users_path
    else
      set_validation_error_notice
      render :new
    end
  end

  def update
    if @user.update_attributes(user_params)
      flash[:success] = "User updated successfully."
      redirect_to_index_or_root
    else
      set_validation_error_notice
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
    permitted += [:admin, :google_email, :household_id] if can?(:manage, User)
    params.require(:user).permit(permitted)
  end

  def redirect_to_index_or_root
    redirect_to can?(:index, User) ? users_path : root_path
  end
end
