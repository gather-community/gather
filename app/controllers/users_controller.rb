class UsersController < ApplicationController
  include Lensable

  helper_method :dummy_user

  before_action -> { nav_context(:people, :directory) }

  def index
    authorize User
    @users = policy_scope(User)
    respond_to do |format|
      format.html do
        prepare_lens({community: {required: true}}, :life_stage, :user_sort, :search)
        @community = current_community
        load_communities_in_cluster
        lens.remove_field(:life_stage) unless policy(dummy_user).index_children_for_community?(@community)
        @users = @users.includes(household: :community)
        @users = @users.in_community(@community)
        @users = @users.matching(lens[:search]) if lens[:search].present?
        @users = @users.in_life_stage(lens[:life_stage]) if lens[:life_stage].present?
        # Regular folks don't care about inactives
        @users = @users.active unless policy(dummy_user).administer?
        if lens[:user_sort].present?
          @users = @users.by_active.sorted_by(lens[:user_sort])
        else
          @users = @users.by_active.by_name
        end
        @users = @users.page(params[:page]).per(36)
        dummy_household = Household.new(community: current_community)
        @allowed_community_changes = policy(dummy_household).allowed_community_changes
      end

      # For select2 lookups
      format.json do
        @users = case params[:context]
        when "lens", "res_sponsor", "reserver_this_cmty", "guardian"
          @users.in_community(current_community).adults
        when "reserver_any_cmty"
          @users.adults
        when "meal_assign"
          @users.in_community(current_community)
        else
          raise "invalid select2 context"
        end
        @users = @users.matching(params[:search]).active
        @users = @users.can_be_guardian if params[:context] == "guardian"
        @users = @users.in_community(params[:community_id]) if params[:community_id]
        @users = @users.by_name.page(params[:page]).per(20)
        render(json: @users, meta: { more: @users.next_page.present? }, root: "results")
      end
    end
  end

  def show
    @user = User.find(params[:id])
    authorize @user
    @households_and_members = @user.all_households.map do |h|
      [h, load_showable_users_and_children_in(h)]
    end.to_h
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
    authorize dummy_user
    @users = User.adults.never_signed_in.active.by_name
  end

  # Expects params[to_invite] = ["1", "5", ...]
  def send_invites
    authorize dummy_user
    if params[:to_invite].blank?
      flash[:error] = "You didn't select any users."
    else
      Delayed::Job.enqueue(People::InviteJob.new(current_community.id, params[:to_invite]))
      flash[:success] = "Invites sent."
      redirect_to(users_path)
    end
  end

  protected

  # See def'n in ApplicationController for documentation.
  def community_for_route
    case params[:action]
    when "show"
      User.find_by(id: params[:id]).try(:community)
    when "index"
      current_user.community
    else
      nil
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
      # It also prevents admins from changing users to a household to which they are not permitted.
      # This is because we set the @user.household above, and THEN check the administer permission.
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

      # This style should only be available if the user is persisted.
      # We need to include the ID in household_attributes or the model assumes we are creating a new one.
      # We copy the existing ID since changing ID via nested attribs is not allowed.
      params[:user][:household_attributes] ||= {}
      params[:user][:household_attributes][:id] = @user.household_id
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
    @user.up_guardianships.build if @user.up_guardianships.empty?
    @user.build_household if @user.household.nil?
    @user.household.vehicles.build if @user.household.vehicles.empty?
    @user.household.emergency_contacts.build if @user.household.emergency_contacts.empty?
  end

  def dummy_user
    User.new(household: Household.new(community: current_community))
  end
end
