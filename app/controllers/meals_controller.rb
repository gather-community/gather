class MealsController < ApplicationController
  include MealShowable

  before_action :init_meal, only: :new

  load_and_authorize_resource

  def index
    load_meals
  end

  def work
    authorize!(:read, Meal)
    params[:uid] = current_user.id unless params.has_key?(:uid)
    @users = User.all
    load_meals
  end

  def show
    @signup = Signup.for(current_user, @meal)
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
    @meals = @meals.future.oldest_first
    @meals = @meals.worked_by(User.find(params[:uid])) if params[:uid].present?
    @meals = @meals.page(params[:page])
  end

  def prep_form_vars
    @meal.ensure_assignments
    @active_users = User.active_or_assigned_to(@meal).by_name
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

      permitted += [:served_at, :host_community_id, :location_id, {
        :head_cook_assign_attributes => [:id, :user_id],
        :asst_cook_assigns_attributes => [:id, :user_id, :_destroy],
        :cleaner_assigns_attributes => [:id, :user_id, :_destroy]
      }]
    end

    params.require(:meal).permit(*permitted)
  end
end
