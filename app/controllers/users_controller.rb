# frozen_string_literal: true

class UsersController < ApplicationController
  include Destructible
  include Lensable

  helper_method :sample_user

  before_action -> { nav_context(:people, :directory) }

  skip_after_action :verify_authorized, only: :unimpersonate

  decorates_assigned :household, :user, :users, :head_cook_meals

  def index
    authorize(User)
    @users = policy_scope(User)
    respond_to do |format|
      format.html do
        load_users

        # Pagination
        if params[:printalbum] || lenses[:view].active_only?
          # We first check for the printalbum param because that overrides any lens pagination stuff.
          # If it's set or if we're only showing active users, we're doing no pagination.
          @users = @users.active
        elsif lenses[:view].albumall?
          @users = @users.page(params[:page]).per(96)
        elsif lenses[:view].tableall?
          @users = @users.page(params[:page]).per(100)
        end

        @users = @users.decorate
        sample_household = Household.new(community: current_community)
        @allowed_community_changes = policy(sample_household).allowed_community_changes

        render(partial: "printable_album") if params[:printalbum]
      end

      # For select2 lookups
      format.json do
        extra_data = params.key?(:data) ? JSON.parse(params[:data]) : nil
        @users = UserSelectScoper.new(scope_name: params[:context], actor: current_user,
                                      community: current_community,
                                      extra_data: extra_data).resolve
        @users = @users.matching(params[:search])
        @users = @users.in_community(params[:community_id]) if params[:community_id]
        @users = @users.page(params[:page]).per(20)
        render(json: @users.decorate, meta: {more: @users.next_page.present?}, root: "results",
               each_serializer: UserSerializer, hide_inactive_in_name: true)
      end

      format.csv do
        load_users
        @users = @users.active # No inactve users in CSV
        @users = @users.includes(household: :vehicles)
        filename = csv_filename(:community, "directory", :date)
        csv = People::CsvExporter.new(@users, policy: policy(sample_user)).to_csv
        send_data(csv, filename: filename, type: :csv)
      end
    end
  end

  def show
    @user = User.find(params[:id])
    authorize(@user)
    @households_and_members = @user.all_households.map do |h|
      [h.decorate, load_showable_users_and_children_in(h)]
    end.to_h
    @head_cook_meals = policy_scope(Meals::Meal).worked_by(@user, head_cook_only: true).includes(:signups)
      .past.not_cancelled.newest_first
    @memberships = @user.group_memberships.positive.by_group_name
  end

  def new
    child = params[:child].present?
    @user = User.new(child: child, full_access: !child, household_by_id: true)
    set_blank_household
    prepare_user_form
    authorize(@user)
  end

  def create
    @user = User.new
    return unless bootstrap_household

    prepare_custom_data_infrastructure
    @user.assign_attributes(permitted_attributes(@user))
    authorize(@user)
    skip_email_confirmation_if_unconfirmed!
    if @user.save
      send_invite_and_flash_on_create
      redirect_to(user_path(@user))
    else
      prepare_user_form
      render(:new)
    end
  end

  def edit
    @user = User.find(params[:id])

    # We don't allow editing household data via a child's form since it's complicated when
    # a child belongs to more than one household. But there needs to be a way for admins
    # to edit the household, so we set household_by_id to true for children which shows the
    # household dropdown. We a show a caveat in the hint so folks don't get worked up about it.
    # We don't need to set this for non-admins since they can't change the household anyway.
    @user.household_by_id = @user.child? && policy(@user).administer?
    authorize(@user)
    prepare_user_form
  end

  def update
    @user = User.find(params[:id])
    return unless bootstrap_household

    authorize(@user)
    skip_email_confirmation_if_unconfirmed!
    prepare_custom_data_infrastructure
    if @user.update(permitted_attributes(@user))
      flash_on_update
      redirect_to(user_path(@user))
    else
      prepare_user_form
      render(:edit)
    end
  end

  def update_setting
    @user = current_user
    authorize(@user)
    new_settings = params.require(:settings)
      .permit(:calendar_popover_dismissed, calendar_selection: params[:settings][:calendar_selection]&.keys)
    @user.settings = (@user.settings || {}).merge(new_settings)
    @user.save!
  end

  def resend_email_confirmation
    @user = User.find(params[:id])
    authorize(@user, :update_info?)
    @user.send_confirmation_instructions
    flash[:success] = "Instructions sent."
    redirect_to(user_path(@user))
  end

  def cancel_email_change
    @user = User.find(params[:id])
    authorize(@user, :update_info?)
    @user.update!(unconfirmed_email: nil, confirmation_token: nil)
    flash[:success] = "Email change canceled."
    redirect_to(user_path(@user))
  end

  def impersonate
    @user = User.find(params[:id])
    authorize(@user)
    session[:impersonating_id] = @user.id
    redirect_to(root_path)
  end

  def unimpersonate
    ActsAsTenant.without_tenant do
      @user = User.find(params[:id])
      session.delete(:impersonating_id)
      redirect_to(url_in_community(@user.community, user_path(@user)))
    end
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
    end
  end

  # Overrides default behavior in Deactivatable concern.
  def after_activate(user)
    return super if user.confirmed?

    flash[:alert] = I18n.t("deactivatable.#{user.model_name.i18n_key}.success.activate_unconfirmed")
  end

  private

  def load_users
    prepare_user_lenses
    @community = current_community
    load_communities_in_cluster
    unless policy(sample_user).index_children_for_community?(@community)
      lenses.remove_lens(:"people/life_stage")
    end
    @users = @users.includes(household: :community)
    @users = @users.in_community(@community)
    @users = @users.matching(lenses[:search].value) if lenses[:search].present?
    @users = @users.in_life_stage(lenses[:lifestage].value) if lenses[:lifestage].present?
    @users = @users.deactivated_last.sorted_by(lenses[:sort].selection.to_s)

    # Regular folks can't see inactive users.
    @users = @users.active unless policy(sample_user).show_inactive?
  end

  def prepare_user_lenses
    prepare_lenses({community: {clearable: false}},
                   :"people/life_stage",
                   {"people/sort":
                     {base_option: current_community.settings.people.default_directory_sort.to_sym}},
                   :"people/view",
                   :search)
  end

  def prepare_custom_data_infrastructure
    # We have to call `custom_data` before `create` and `update` (AND after the user's community is set)
    # to trigger the CustomFields infrastructure to set things
    # up. Otherwise update bypasses the CustomFields infrastructure altogether.
    @user.custom_data
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
      @user.household = Household.find_by(id: params[:user][:household_id])

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
        # We have to put in a dummy community before we assign attribs or custom fields will fail.
        @user.build_household(community: current_community)
        @user.assign_attributes(params[:user].permit!)
        @user.validate
        skip_authorization
        set_blank_household
        prepare_user_form
        render(@user.new_record? ? :new : :edit)
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
    true
  end

  # Sets a blank, unpersisted household that will be acceptable to the policy.
  def set_blank_household
    @user.household = Household.new(community: current_community)
  end

  def prepare_user_form
    @user.up_guardianships.build if @user.up_guardianships.empty?
    @user.household.build_blank_associations
    @user.household = @user.household.decorate
    @max_photo_size = User.validators_on(:photo).detect { |v| v.is_a?(FileSizeValidator) }.options[:max]
    @member_types = People::MemberType.in_community(@user.community).by_name
  end

  def sample_user
    User.new(household: Household.new(community: current_community))
  end

  def skip_email_confirmation_if_unconfirmed!
    # Per app policy, users that are unconfirmed can only sign in via an invite email, which also
    # confirms their email address. So there is no need to also send a confirmation email to these folks
    # when saving them. This is applicable to both create (trivially) and update.
    # Wo DO still want to keep confirmed_at set to NULL since that is still true and we want to be able
    # to rely on that flag elsewhere.
    # However, on update, there is no need to reconfirm (storing new email in unconfirmed_email), and doing so
    # will result in the invite going to the wrong email if e.g. the admin makes a mistake entering the
    # email of a new user and then goes back and corrects it.
    # See the User class for more documentation on email confirmation.
    return if @user.confirmed?

    @user.skip_confirmation_notification!
    @user.skip_reconfirmation!
  end

  def send_invite_and_flash_on_create
    if params[:save_and_invite]
      People::SignInInvitationJob.perform_later(current_community.id, [@user.id])
      flash[:success] = "User created and invited successfully."
    else
      flash[:success] = "User created successfully."
    end
  end

  def flash_on_update
    # Unlike with create, confirmation instructions are sent automatically by Devise because
    # we didn't opt out of them.
    msg = @user == current_user ? +"Profile updated successfully." : +"User updated successfully."
    if @user.unconfirmed_email?
      if @user == current_user
        msg << " You need to confirm your new email address. "
        msg << "Please check your email at #{@user.unconfirmed_email}."
      else
        msg << " This user needs to confirm their new email address (#{@user.unconfirmed_email})."
      end
      flash[:alert] = msg
    # If a user's email address changes, Devise automatically deletes the password reset token for
    # security purposes. So let's let them know that.
    elsif @user.saved_change_to_reset_password_token? && @user.reset_password_token.blank?
      msg << " However, this change may have invalidated a sign-in invitation.
        You may want to send a new one."
      flash[:alert] = msg
    else
      flash[:success] = msg
    end
  end
end
