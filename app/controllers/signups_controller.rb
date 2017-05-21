class SignupsController < ApplicationController
  include MealShowable

  before_action -> { nav_context(:meals) }

  def create
    @signup = Signup.new(household_id: current_user.household_id)
    @signup.assign_attributes(permitted_attributes(@signup))
    authorize @signup
    if @signup.save_or_destroy
      redirect_after_save
    else
      render_meal_show
    end
  end

  def update
    @signup = Signup.find(params[:id])
    authorize @signup
    @signup.assign_attributes(permitted_attributes(@signup))
    if @signup.save_or_destroy
      redirect_after_save
    else
      render_meal_show
    end
  end

  private

  def redirect_after_save
    meals_root = url_in_home_community(meals_path)
    if params[:save_and_next]
      next_meal = (id = params[:next_meal_id]).present? ? Meal.find(id) : nil
      redirect_to(next_meal ? meal_url(next_meal) : meals_root)
    else
      policy(dummy_meal).index? ? redirect_to(meals_root) : redirect_to_home
    end
  end

  def render_meal_show
    @meal = @signup.meal
    @signups = @meal.signups.includes(household: :community).sorted
    authorize @meal, :show?
    load_prev_next_meal # From MealShowable
    render("meals/show")
  end
end
