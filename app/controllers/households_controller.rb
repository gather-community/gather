# frozen_string_literal: true

class HouseholdsController < ApplicationController
  include Destructible
  include Lensable

  before_action -> { nav_context(:people, :households) }

  decorates_assigned :household, :members

  def index
    authorize(Household.new(community: current_community))
    @households = policy_scope(Household)
    respond_to do |format|
      format.html { index_html }
      format.json { index_json }
    end
  end

  def show
    @household = Household.find(params[:id])
    @members = load_showable_users_and_children_in(@household)
    authorize(@household)
  end

  def new
    @household = Household.new(community: current_community)
    authorize(@household)
    prepare_household_form
  end

  def create
    @household = Household.new(community: current_community)
    @household.assign_attributes(household_attributes)
    authorize(@household)
    if @household.save
      flash[:success] = "Household created successfully."
      redirect_to(households_path)
    else
      prepare_household_form
      render(:new)
    end
  end

  def edit
    @household = Household.find(params[:id])
    authorize(@household)
    prepare_household_form
  end

  def update
    @household = Household.find(params[:id])
    authorize(@household)
    if @household.update(household_attributes)
      flash[:success] = "Household updated successfully."
      redirect_to(households_path)
    else
      prepare_household_form
      render(:edit)
    end
  end

  protected

  def klass
    Household
  end

  # See def'n in ApplicationController for documentation.
  def community_for_route
    case params[:action]
    when "show"
      Household.find_by(id: params[:id]).try(:community)
    when "index"
      current_user.community
    end
  end

  private

  def index_html
    prepare_lenses({community: {required: true}}, :"people/sort", :search)
    @households = @households.includes(users: :children)
    @households = @households.by_active.ordered_by(lenses[:sort].value)
    @households = @households.in_community(current_community)
    @households = @households.matching(lenses[:search].value) if lenses[:search].present?
    @households = @households.page(params[:page])
  end

  # For select2 lookups
  def index_json
    @households = @households.active.matching(params[:search])
    @households =
      case params[:context]
      when "meal_form"
        @households # No further scoping needed for meal form/finalize
      when "user_form"
        # Instead of the usual scope.resolve.
        scope(@households).administerable.in_community(current_community)
      else
        raise "invalid select2 context"
      end
    @households = @households.by_commty_and_name.page(params[:page]).per(20)
    render(json: @households, meta: {more: @households.next_page.present?}, root: "results")
  end

  def scope(relation)
    HouseholdPolicy::Scope.new(current_user, relation)
  end

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
