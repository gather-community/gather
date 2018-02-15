class UsersController < ApplicationController
  include Lensable, Destructible

  helper_method :sample_user

  before_action -> { nav_context(:people, :directory) }

  decorates_assigned :household, :user

  def index
    authorize User
    @users = policy_scope(User)
    respond_to do |format|
      format.html do
        load_users

        # Pagination
        if params[:printalbum] || lenses[:user_view] == "table"
          # We first check for the printalbum param because that overrides any lens pagination stuff.
          # If it's set, (or if view is 'table') we're showing all active users with no pagination.
          @users = @users.active
        elsif lenses[:user_view].blank? || lenses[:user_view] == "album"
          @users = @users.page(params[:page]).per(36)
        elsif lenses[:user_view] == "tableall"
          @users = @users.page(params[:page]).per(100)
        end

        @users = @users.decorate
        sample_household = Household.new(community: current_community)
        @allowed_community_changes = policy(sample_household).allowed_community_changes

        render(partial: "printable_album") if params[:printalbum]
      end

      # For select2 lookups
      format.json do
        @users = case params[:context]
        when "res_sponsor", "reserver_this_cmty", "guardian"
          @users.in_community(current_community).adults
        when "reserver_any_cmty"
          @users.adults
        when "lens", "meal_assign"
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

      format.csv do
        load_users
        @users = @users.active # No inactve users in CSV
        filename = csv_filename(:community, "directory", :date)
        send_data People::Exporter.new(@users).to_csv, filename: filename, type: :csv
      end
    end
  end

  def show
    @user = User.find(params[:id])
    authorize @user
    @households_and_members = @user.all_households.map do |h|
      [h.decorate, load_showable_users_and_children_in(h)]
    end.to_h
    @head_cook_meals = policy_scope(Meal).head_cooked_by(@user).includes(:signups).
      past.not_cancelled.newest_first
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
      set_validation_error_notice(@user)
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
      set_validation_error_notice(@user)
      prepare_user_form
      render :edit
    end
  end

  def invite
    authorize sample_user
    @users = User.in_community(current_community).adults.never_signed_in.active.by_name
  end

  # Expects params[to_invite] = ["1", "5", ...]
  def send_invites
    authorize sample_user
    if params[:to_invite].blank?
      flash[:error] = "You didn't select any users."
    else
      Delayed::Job.enqueue(People::InviteJob.new(current_community.id, params[:to_invite]))
      flash[:success] = "Invites sent."
      redirect_to(users_path)
    end
  end

  def impersonate
    @user = User.find(params[:id])
    authorize @user
    session[:impersonating_id] = @user.id
    redirect_to root_path
  end

  def unimpersonate
    @user = User.find(params[:id])
    skip_authorization
    session.delete(:impersonating_id)
    redirect_to user_path(@user)
  end

  protected

  def klass
    User
  end

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

  def load_users
    prepare_lenses({community: {required: true}}, :people_life_stage, :people_sort, :people_view, :search)
    @community = current_community
    load_communities_in_cluster
    lenses.remove_lens(:life_stage) unless policy(sample_user).index_children_for_community?(@community)
    @users = @users.includes(household: :community)
    @users = @users.in_community(@community)
    @users = @users.matching(lenses[:search]) if lenses[:search].present?
    @users = @users.in_life_stage(lenses[:life_stage]) if lenses[:life_stage].present?

    # Regular folks can't see inactive users.
    @users = @users.active unless policy(sample_user).show_inactive?

    if lenses[:user_sort].present?
      @users = @users.by_active.sorted_by(lenses[:user_sort])
    else
      @users = @users.by_active.by_name
    end
  end

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
        set_validation_error_notice(@user)
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
    @user.household.build_blank_associations
    @user.household = @user.household.decorate
  end

  def sample_user
    User.new(household: Household.new(community: current_community))
  end
end
