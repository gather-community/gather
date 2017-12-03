class HouseholdsController < ApplicationController
  include Lensable, AccountShowable, Destructible

  before_action -> { nav_context(:people, :households) }, except: :accounts

  decorates_assigned :household

  def index
    authorize Household.new(community: current_community)
    @households = policy_scope(Household)
    respond_to do |format|
      format.html do
        prepare_lens({community: {required: true}}, :search)
        @households = @households.includes(users: :children)
        @households = @households.in_community(current_community)
        @households = @households.matching(lens[:search]) if lens[:search].present?
        @households = @households.by_active_and_name.page(params[:page])
      end

      # For select2 lookups
      format.json do
        @households = @households.active.matching(params[:search])
        @households = case params[:context]
        when "finalize"
          @households # No further scoping needed for finalize
        when "user_form"
          HouseholdPolicy::Scope.new(current_user, @households).administerable.in_community(current_community)
        else
          raise "invalid select2 context"
        end
        @households = @households.by_commty_and_name.page(params[:page]).per(20)
        render(json: @households, meta: { more: @households.next_page.present? }, root: "results")
      end
    end
  end

  def show
    @household = Household.find(params[:id])
    @members = load_showable_users_and_children_in(@household)
    authorize @household
  end

  def new
    @household = Household.new(community: current_community)
    authorize @household
    prepare_household_form
  end

  def create
    @household = Household.new(community: current_community)
    @household.assign_attributes(household_attributes)
    authorize @household
    if @household.save
      flash[:success] = "Household created successfully."
      redirect_to households_path
    else
      set_validation_error_notice(@household)
      prepare_household_form
      render :new
    end
  end

  def edit
    @household = Household.find(params[:id])
    authorize @household
    prepare_household_form
  end

  def update
    @household = Household.find(params[:id])
    authorize @household
    if @household.update_attributes(household_attributes)
      flash[:success] = "Household updated successfully."
      redirect_to households_path
    else
      set_validation_error_notice(@household)
      prepare_household_form
      render :edit
    end
  end

  def accounts
    @household = Household.find(params[:id])
    authorize @household

    @accounts = policy_scope(@household.accounts).includes(:community).to_a

    if @accounts.size > 1
      prepare_lens(community: {required: true, subdomain: false})
      @community = if lens[:community].try(:match, Community::SLUG_REGEX)
        Community.find_by(slug: lens[:community])
      elsif lens[:community].try(:match, /\d+/)
        Community.find(lens[:community])
      end
    end

    @community ||= current_user.community
    @communities = @accounts.map(&:community)
    @account = @accounts.detect { |a| a.community_id == @community.id } || @accounts.first

    prep_account_vars if @account
  end

  protected

  def klass
    Household
  end

  # See def'n in ApplicationController for documentation.
  def community_for_route
    case params[:action]
    when "show", "accounts"
      Household.find_by(id: params[:id]).try(:community)
    when "index"
      current_user.community
    else
      nil
    end
  end

  private

  def household_attributes
    params[:household][:community_id] = current_community.id unless multi_community?
    permitted_attributes(@household).tap do |permitted|
      policy(@household).ensure_allowed_community_id(permitted)
    end
  end

  def prepare_household_form
    sample_household = Household.new(community: current_community)
    @allowed_community_changes = policy(sample_household).allowed_community_changes.by_name
    @household.build_blank_associations
  end
end
