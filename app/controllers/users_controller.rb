class UsersController < ApplicationController
  include Lensable

  before_action -> { nav_context(:people) }

  def index
    @users = policy_scope(User)
    respond_to do |format|
      format.html do
        nav_context(:people, :directory)
        prepare_lens(:community, :search)
        load_communities
        @users = @users.includes(household: :community)
        if lens[:search].present?
          @users = @users.matching(lens[:search])
        end
        if lens[:community].present?
          @users = @users.in_community(Community.find_by_abbrv(lens[:community]))
        end
        @users = @users.by_active_and_name.page(params[:page])
        @allowed_community_changes = policy(Household).allowed_community_changes
      end
      format.json do
        @users = @users.matching(params[:search]).active
        if params[:guardians]
          @users = @users.can_be_guardian
        end
        if params[:community_id]
          @users = @users.in_community(params[:community_id])
        end
        @users = @users.by_name.page(params[:page]).per(20)
        render(json: @users, meta: { more: @users.next_page.present? }, root: "results")
      end
    end
  end

  def show
    @user = User.find(params[:id])
    authorize @user
    @head_cook_meals = policy_scope(Meal).head_cooked_by(@user).includes(:signups).past.newest_first
  end

  def new
    @user = User.new(child: params[:child].present?, household_by_id: true)
    set_blank_household
    prepare_user_form
    authorize @user
  end

  def create
    @user = User.new
    return unless bootstrap_household
    @user.assign_attributes(permitted_attributes(@user))
    authorize @user
    if @user.save
      flash[:success] = "User created successfully."
      redirect_to user_path(@user)
    else
      set_validation_error_notice
      prepare_user_form
      render :new
    end
  end

  def edit
    @user = User.find(params[:id])
    @user.household_by_id = false
    authorize @user
    prepare_user_form
  end

  def update
    @user = User.find(params[:id])
    return unless bootstrap_household
    authorize @user
    if @user.update_attributes(permitted_attributes(@user))
      flash[:success] = "User updated successfully."
      redirect_to user_path(@user)
    else
      set_validation_error_notice
      prepare_user_form
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
      Delayed::Job.enqueue(People::InviteJob.new(params[:to_invite]))
      flash[:success] = "Invites sent."
      redirect_to(users_path)
    end
  end

  private

  # Called before authorization to check and prepare household attributes.
  # We need to set the household separately from the other parameters because
  # the household is what determines the community, and that determines what attributes
  # are permitted to be set. So we don't allow household_id or household_attributes.id
  # through permitted_attributes.
  # Checks params[:household_by_id]. If 'true', we discard household_attributes.
  # If 'false', we discard household_id.
  def bootstrap_household
    case params[:user][:household_by_id]
    when "true"
      # Don't need this.
      params[:user].delete(:household_attributes)

      # We set the household here so that the UserPolicy can use it.
      @user.household = Household.find_by_id(params[:user][:household_id])

      # This prevents non-admins (e.g. self, parent) from changing their household.
      # This would normally be something checked by UserPolicy.permitted_attributes, but since we are
      # bootstrapping, that object is not available yet.
      if @user.household_id_changed? && !policy(@user).administer?
        raise Pundit::NotAuthorizedError, "Can't change household without administer permission"
      end

      # If household was not found, validation needs to fail, but the Policy won't let us get that far, so
      # we have to work around it. We can use permit! since we know these attribs will not be saved.
      if @user.household.nil?
        @user.assign_attributes(params[:user].permit!)
        @user.validate
        skip_authorization
        set_blank_household
        set_validation_error_notice
        render @user.new_record? ? :new : :edit
        return false
      end
    when "false"
      # Don't need this.
      params[:user].delete(:household_id)

      # If the user is persisted, we know it must already have a household, so we are done.
      # We just need to copy the household ID to the nested params,
      # or the model assumes we are creating a new one.
      if @user.persisted?
        # We need to include the ID in household_attributes or the model assumes we are creating a new one.
        # We copy the existing ID since changing ID via nested attribs is not allowed.
        params[:user][:household_attributes][:id] = @user.household_id
      else
        # Otherwise, we have to create a blank community with the given community_id.
        # The other attributes will be filled in by normal nested assignment.
        @user.build_household(community_id: params[:user][:household_attributes][:community_id])
      end
    else
      raise "household_by_id is required for this action"
    end

    # If we get to here, it means we have assigned the household and it hasn't changed without the
    # administer permission. So we can return to the main method and use the normal `authorize` method
    # which will check that the current_user has the appropriate permissions to create/update a user
    # with the given household.
    return true
  end

  # Sets a blank, unpersisted household that will be acceptable to the policy.
  def set_blank_household
    @user.household = Household.new(community: current_community)
  end

  def prepare_user_form
    @allowed_community_changes = policy(Household).allowed_community_changes.by_name
    @user.up_guardianships.build if @user.up_guardianships.empty?
    @user.build_household if @user.household.nil?
    @user.household.vehicles.build if @user.household.vehicles.empty?
    @user.household.emergency_contacts.build if @user.household.emergency_contacts.empty?
  end
end
