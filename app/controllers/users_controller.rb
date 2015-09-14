class UsersController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html do
        @users = @users.by_active_and_name
        @users = @users.matching(params[:search]) if params[:search]
        @users = @users.page(params[:page])
      end
      format.json do
        @users = @users.matching(params[:search]).active.by_name.page(params[:page]).per(20)
        render(json: @users, meta: { more: @users.next_page.present? })
      end
    end
  end

  def new
    @user = User.new
  end

  def show
  end

  def invite
    @users = User.never_logged_in.active.by_community_and_name
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
    @user.destroy
    flash[:success] = "User deleted successfully."
    redirect_to(users_path)
  end

  def activate
    @user.activate!
    flash[:success] = "User activated successfully."
    redirect_to(users_path)
  end

  def deactivate
    @user.deactivate!
    flash[:success] = "User deactivated successfully."
    redirect_to(users_path)
  end

  # Expects params[to_invite] = ["1", "5", ...]
  def send_invites
    if (params[:to_invite] || []).size > 20
      flash[:error] = "You can only invite up to 20 users at a time."
      redirect_to(invite_users_path)
    else
      @users = User.find(params[:to_invite])
      if @users.empty?
        flash[:error] = "You didn't select any users."
      else
        @users.each{ |u| u.send_reset_password_instructions }
        flash[:success] = "Invites sent."
      end
      redirect_to(users_path)
    end
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
