class MealsController < ApplicationController
  include MealShowable, Lensable

  decorates_assigned :meals

  before_action :init_meal, only: :new
  before_action :create_worker_change_notifier, only: :update
  before_action -> { nav_context(:meals, :meals) }, except: [:jobs, :report]

  def index
    prepare_lenses(:search, :"meals/time", :community)

    authorize sample_meal
    load_meals(:index)
    load_communities_in_cluster
  end

  def jobs
    authorize sample_meal
    nav_context(:meals, :jobs)
    prepare_lenses(:"people/user", :"meals/time")
    @user = User.find(lenses[:user].value) if lenses[:user].present?
    load_meals(:jobs)
    load_communities_in_cluster
  end

  def show
    @meal = Meal.find(params[:id]).decorate
    authorize @meal

    # Don't want the singup form to get cached
    set_no_cache unless @meal.in_past?

    flash.now[:error] = I18n.t("meals.cancelled_notice") if @meal.cancelled?

    @signup = Signup.for(current_user, @meal)
    @household = current_user.household.decorate
    @account = current_user.account_for(@meal.community).try(:decorate)
    load_signups
    load_prev_next_meal
  end

  def report
    authorize sample_meal, :report?
    @community = current_community
    nav_context(:meals, :report)
    prepare_lenses(*report_lenses)
    @report = Meals::Report.new(@community, range: lenses[:dates].range)
    @communities = Community.by_name_with_first(@community).to_a
  end

  def new
    authorize @meal
    @min_date = Time.zone.today.strftime("%Y-%m-%d")
    prep_form_vars
  end

  def edit
    @meal = Meal.find(params[:id])
    authorize @meal
    @min_date = nil
    @notify_on_worker_change = !policy(@meal).administer?
    prep_form_vars
  end

  def create
    @meal = Meal.new(
      community_id: current_user.community_id,
      community_ids: [current_user.community_id],
      creator: current_user
    )
    @meal.assign_attributes(permitted_attributes(@meal))
    @meal.build_reservations
    authorize @meal
    if @meal.save
      flash[:success] = "Meal created successfully."
      redirect_to meals_path
    else
      set_validation_error_notice(@meal)
      prep_form_vars
      render :new
    end
  end

  def update
    @meal = Meal.find(params[:id])
    authorize @meal
    @meal.assign_attributes(permitted_attributes(@meal))
    @meal.build_reservations
    if @meal.save
      flash[:success] = "Meal updated successfully."
      @worker_change_notifier.try(:check_and_send!)
      redirect_to meals_path
    else
      set_validation_error_notice(@meal)
      prep_form_vars
      render :edit
    end
  end

  def close
    @meal = Meal.find(params[:id])
    authorize @meal
    @meal.close!
    flash[:success] = "Meal closed successfully."
    redirect_to(meals_path)
  end

  def finalize
    @meal = Meal.find(params[:id])
    authorize @meal
    @meal.build_cost
    @dupes = []
  end

  def do_finalize
    @meal = Meal.find(params[:id])
    authorize @meal, :finalize?

    # We assign finalized here so that the meal/signup validations don't complain about no spots left.
    @meal.assign_attributes(finalize_params.merge(status: "finalized"))

    if (@dupes = @meal.duplicate_signups).any?
      flash.now[:error] = "There are duplicate signups. "\
        "Please correct by adding numbers for each diner type."
      render(:finalize)
    elsif @meal.valid?
      # Run the save and signup in a transaction in case the finalize operation fails.
      # Save the meal first so that any signups marked for deletion are deleted.
      Meal.transaction do
        @meal.save!
        Meals::Finalizer.new(@meal).finalize!
      end
      flash[:success] = "Meal finalized successfully"
      redirect_to(meals_path(finalizable: 1))
    else
      set_validation_error_notice(@meal)
      render(:finalize)
    end
  end

  def reopen
    @meal = Meal.find(params[:id])
    authorize @meal
    @meal.reopen!
    flash[:success] = "Meal reopened successfully."
    redirect_to(meals_path)
  end

  def summary
    @meal = Meal.find(params[:id]).decorate
    authorize @meal
    load_signups
    @cost_calculator = MealCostCalculator.build(@meal)
    if @meal.open? && current_user == @meal.head_cook
      flash.now[:alert] = "Note: This meal is not yet closed and people can still sign up for it. "\
        "You should close the meal using the link below before printing this summary."
    end
  end

  def destroy
    @meal = Meal.find(params[:id])
    authorize @meal
    if @meal.destroy
      flash[:success] = "Meal deleted successfully."
    else
      flash[:error] = "Meal deletion failed."
    end
    redirect_to(meals_path)
  end

  protected

  def default_url_options
    {mode: params[:mode]}
  end

  # See def'n in ApplicationController for documentation.
  def community_for_route
    case params[:action]
    when "show", "summary"
      Meal.find_by(id: params[:id]).try(:community)
    when "index", "jobs", "report", "reports"
      current_user.community
    end
  end

  private

  def init_meal
    @meal = Meal.new_with_defaults(current_community)
  end

  def load_meals(context)
    @meals = policy_scope(Meal)
    @meals = @meals.hosted_by(context == :index ? lens_communities : current_community)
    @meals = @meals.worked_by(lenses[:user].value) if lenses[:user].present?

    if lenses[:time].finalizable?
      @meals = @meals.finalizable.where(community_id: current_community).oldest_first
    elsif lenses[:time].past?
      @meals = @meals.past.newest_first
    elsif lenses[:time].all?
      @meals = @meals.oldest_first
    else
      @meals = @meals.future.oldest_first
    end
    @meals = @meals.includes(:signups)
    if params[:search].present?
      @meals = @meals.eager_load(:head_cook).
        where("title ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ?",
          "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    @meals = @meals.page(params[:page])
  end

  def load_signups
    @signups = @meal.signups.community_first(@meal.community).sorted.decorate
  end

  def prep_form_vars
    @meal = @meal.decorate
    @meal.ensure_assignments
    load_communities_in_cluster
    @formula_options = policy_scope(Meals::Formula).for_community(current_community).
      active_or_selected(@meal.formula).by_name
    @resource_options = policy_scope(Reservations::Resource).active.meal_hostable.by_cmty_and_name.decorate
    @sample_formula = Meals::Formula.new(community: current_community)
    @sample_resource = Reservations::Resource.new(community: current_community)
  end

  def create_worker_change_notifier
    @meal = Meal.find(params[:id])
    if !policy(@meal).administer?
      @worker_change_notifier = Meals::WorkerChangeNotifier.new(current_user, @meal)
    end
  end

  def report_lenses
    first_meal_date = Meal.minimum(:served_at).to_date
    result = []
    result << {date_range: {min_date: first_meal_date}}
    result << {community: {required: true}} if multi_community?
    result
  end
end
