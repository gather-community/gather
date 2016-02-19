class UsersController < ApplicationController

  def index
    @users = policy_scope(User)
    respond_to do |format|
      format.html do
        @users = @users.includes(household: :community).by_active_and_name
        @users = @users.matching(params[:search]) if params[:search]
        @users = @users.page(params[:page])
      end
      format.json do
        @users = @users.matching(params[:search]).active.by_name.page(params[:page]).per(20)
        render(json: @users, meta: { more: @users.next_page.present? })
      end
    end
  end

  def show
    @user = User.find(params[:id])
    authorize @user
    @head_cook_meals = Meal.head_cooked_by(@user).includes(:signups).past.newest_first
  end

  def new
    @user = User.new
    authorize @user
  end

  def create
    @user = User.new
    authorize @user
    @user.assign_attributes(permitted_attributes(@user))
    if @user.save
      flash[:success] = "User created successfully."
      redirect_to users_path
    else
      set_validation_error_notice
      render :new
    end
  end

  def edit
    @user = User.find(params[:id])
    authorize @user
  end

  def update
    @user = User.find(params[:id])
    authorize @user
    if @user.update_attributes(permitted_attributes(@user))
      flash[:success] = "User updated successfully."
      redirect_to_index_or_root
    else
      set_validation_error_notice
      render :edit
    end
  end

  def destroy
    @user = User.find(params[:id])
    authorize @user
    @user.destroy
    flash[:success] = "User deleted successfully."
    redirect_to(users_path)
  end

  def activate
    @user = User.find(params[:id])
    authorize @user
    @user.activate!
    flash[:success] = "User activated successfully."
    redirect_to(users_path)
  end

  def deactivate
    @user = User.find(params[:id])
    authorize @user
    @user.deactivate!
    flash[:success] = "User deactivated successfully."
    redirect_to(users_path)
  end

  def invite
    authorize User
    @users = User.never_logged_in.active.by_community_and_name
  end

  # Expects params[to_invite] = ["1", "5", ...]
  def send_invites
    authorize User
    if params[:to_invite].blank?
      flash[:error] = "You didn't select any users."
    else
      Delayed::Job.enqueue(InviteJob.new(params[:to_invite]))
      flash[:success] = "Invites sent."
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
