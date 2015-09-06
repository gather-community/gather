class UsersController < ApplicationController
  load_and_authorize_resource

  def index
    @users = User.by_active_and_name.page(params[:page])
  end

  def new
    @user = User.new
  end

  def show
  end

  def invite
    @users = User.never_logged_in.active.by_name
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

  # Expects params[to_invite] = ["1", "5", ...]
  def send_invites
    @users = User.find(params[:to_invite])
    if @users.empty?
      flash[:error] = "You didn't select any users"
    else
      @users.each{ |u| u.send_reset_password_instructions }
      flash[:success] = "Invites sent."
    end
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
