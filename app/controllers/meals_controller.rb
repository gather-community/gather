class MealsController < ApplicationController
  include MealShowable

  before_action :init_meal, only: :new

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
    @reimb_request = ReimbursementRequest.new
    @dupes = []
  end

  def do_finalize
    @reimb_request = ReimbursementRequest.new
    @reimb_request.assign_attributes(reimb_request_params)
    params[:meal].delete(:reimbursement_request)

    @meal.assign_attributes(finalize_params.merge(status: "finalized"))

    if (@dupes = @meal.duplicate_signups).any?
      flash.now[:error] = "There are duplicate signups. "\
        "Please correct by adding numbers for each diner type."
      render(:finalize)
    elsif @reimb_request.valid?
      @meal.save! # Should be no validation issues
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
      @meals = @meals.finalizable.oldest_first
    elsif params[:past]
      @meals = @meals.past.newest_first
    else
      @meals = @meals.future.oldest_first
    end
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
    permitted = [:title, :capacity, :entrees, :side, :kids, :dessert, :notes, :allergen_gluten,
      :allergen_shellfish, :allergen_soy, :allergen_corn, :allergen_dairy, :allergen_eggs,
      :allergen_peanuts, :allergen_almonds, :allergen_none,
      { :community_boxes => [Community.all.map(&:id).map(&:to_s)] }
    ]

    if can?(:manage, Meal)
      # Hardcoding this for now
      params[:meal][:host_community_id] = current_user.community_id

      permitted += [:discount, :served_at, :host_community_id, :location_id, {
        :head_cook_assign_attributes => [:id, :user_id],
        :asst_cook_assigns_attributes => [:id, :user_id, :_destroy],
        :cleaner_assigns_attributes => [:id, :user_id, :_destroy]
      }]
    end

    params.require(:meal).permit(*permitted)
  end

  def finalize_params
    params.require(:meal).permit(signups_attributes:
      [:id, :household_id, :_destroy] + Signup::SIGNUP_TYPES)
  end

  def reimb_request_params
    params.require(:meal).require(:reimbursement_request).
      permit(:ingredient_cost, :pantry_cost, :payment_method)
  end
end
