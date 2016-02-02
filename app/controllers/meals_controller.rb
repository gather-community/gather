class MealsController < ApplicationController
  include MealShowable

  before_action :init_meal, only: :new
  before_action :create_worker_change_notifier, only: :update

  load_and_authorize_resource

  def index
    # Trivially, a meal in the past must be closed.
    Meal.close_all_past!
    load_meals
  end

  def work
    authorize!(:read, Meal)
    @user = params.has_key?(:uid) ? User.find_by(id: params[:uid]) : current_user
    load_meals
  end

  def show
    @signup = Signup.for(current_user, @meal)
    @account = current_user.account_for(@meal.host_community)
    load_signups
    load_prev_next_meal
  end

  def new
    @min_date = Date.today.strftime("%Y-%m-%d")
    prep_form_vars
  end

  def edit
    @meal = Meal.find(params[:id])
    @min_date = nil
    @notify_on_worker_change = cannot?(:manage, @meal)
    prep_form_vars
  end

  def create
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
    if @meal.update_attributes(meal_params)
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
    @meal.close!
    flash[:success] = "Meal closed successfully."
    redirect_to(meals_path)
  end

  def finalize
    @dupes = []
  end

  def do_finalize
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
    @meal.reopen!
    flash[:success] = "Meal reopened successfully."
    redirect_to(meals_path)
  end

  def summary
    load_signups
    @cost_calculator = MealCostCalculator.build(@meal)
    if @meal.open?
      flash.now[:alert] = "Note: This meal is not yet closed and people can still sign up for it. "\
        "You should close the meal using the link below before printing this summary."
    end
  end

  def destroy
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
  end

  def meal_params
    # Anybody that can update a meal can change the assignments.
    permitted = [{
      :head_cook_assign_attributes => [:id, :user_id],
      :asst_cook_assigns_attributes => [:id, :user_id, :_destroy],
      :cleaner_assigns_attributes => [:id, :user_id, :_destroy]
    }]

    if can?(:set_menu, Meal)
      allergens = Meal::ALLERGENS.map{ |a| :"allergen_#{a}" }
      permitted += allergens + [:title, :capacity, :entrees, :side, :kids, :dessert, :notes,
        { :community_boxes => [Community.all.map(&:id).map(&:to_s)] }
      ]
    end

    if can?(:manage, Meal)
      # Hardcoding this for now
      params[:meal][:host_community_id] = current_user.community_id
      permitted += [:discount, :served_at, :host_community_id, :location_id]
    end

    params.require(:meal).permit(*permitted)
  end

  def finalize_params
    params.require(:meal).permit(:ingredient_cost, :pantry_cost, :payment_method, signups_attributes:
      [:id, :household_id, :_destroy] + Signup::SIGNUP_TYPES)
  end

  def create_worker_change_notifier
    @meal = Meal.find(params[:id])
    if cannot?(:manage, @meal)
      @worker_change_notifier = Meals::WorkerChangeNotifier.new(current_user, @meal)
    end
  end
end
