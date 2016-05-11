class MealsController < ApplicationController
  include MealShowable

  before_action :init_meal, only: :new
  before_action :create_worker_change_notifier, only: :update

  def index
    # Trivially, a meal in the past must be closed.
    authorize Meal
    Meal.close_all_past!
    load_meals
  end

  def work
    authorize Meal, :index?
    @user = params.has_key?(:uid) ? User.find_by(id: params[:uid]) : current_user
    load_meals
  end

  def show
    @meal = Meal.find(params[:id])
    authorize @meal

    # Don't want the singup form to get cached
    set_no_cache unless @meal.in_past?

    @signup = Signup.for(current_user, @meal)
    @account = current_user.account_for(@meal.host_community)
    load_signups
    load_prev_next_meal
  end

  def new
    authorize @meal
    @min_date = Date.today.strftime("%Y-%m-%d")
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
      host_community_id: current_user.community_id,
      creator: current_user
    )
    @meal.assign_attributes(permitted_attributes(@meal))
    @meal.sync_reservations
    authorize @meal
    if @meal.save
      flash[:success] = "Meal created successfully."
      redirect_to meals_path
    else
      set_validation_error_notice
      prep_form_vars
      render :new
    end
  end

  def update
    @meal = Meal.find(params[:id])
    authorize @meal
    @meal.assign_attributes(permitted_attributes(@meal))
    @meal.sync_reservations
    if @meal.save
      flash[:success] = "Meal updated successfully."
      @worker_change_notifier.try(:check_and_send!)
      redirect_to meals_path
    else
      set_validation_error_notice
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
    @dupes = []
  end

  def do_finalize
    @meal = Meal.find(params[:id])
    authorize @meal, :finalize?
    @meal.assign_attributes(finalize_params.merge(status: "finalized"))

    if (@dupes = @meal.duplicate_signups).any?
      flash.now[:error] = "There are duplicate signups. "\
        "Please correct by adding numbers for each diner type."
      render(:finalize)
    elsif @meal.valid?
      Meal.transaction do
        @meal.save
        Finalizer.new(@meal).finalize!
      end
      flash[:success] = "Meal finalized successfully"
      redirect_to(meals_path(finalizable: 1))
    else
      set_validation_error_notice
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
    @meal = Meal.find(params[:id])
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

  private

  def init_meal
    @meal = Meal.new_with_defaults(current_user)
  end

  def load_meals
    @meals = policy_scope(Meal)
    if params[:finalizable]
      @meals = @meals.finalizable.where(host_community_id: current_user.community_id).oldest_first
    elsif params[:past]
      @meals = @meals.past.newest_first
    else
      @meals = @meals.future.oldest_first
    end
    @meals = @meals.includes(:signups)
    @meals = @meals.worked_by(@user) if @user.present?
    @meals = @meals.page(params[:page])
  end

  def load_signups
    @signups = @meal.signups.host_community_first(@meal.host_community).sorted
  end

  def prep_form_vars
    @meal.ensure_assignments
    @communities = Community.by_name
    @resource_options = Reservation::Resource.meal_hostable.by_full_name
  end

  def finalize_params
    params.require(:meal).permit(:ingredient_cost, :pantry_cost, :payment_method, signups_attributes:
      [:id, :household_id, :_destroy] + Signup::SIGNUP_TYPES)
  end

  def create_worker_change_notifier
    @meal = Meal.find(params[:id])
    if !policy(@meal).administer?
      @worker_change_notifier = Meals::WorkerChangeNotifier.new(current_user, @meal)
    end
  end
end
