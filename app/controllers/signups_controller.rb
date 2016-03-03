class SignupsController < ApplicationController
  include MealShowable

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
    if params[:save_and_next]
      next_meal = (id = params[:next_meal_id]).present? ? Meal.find(id) : nil
      redirect_to(next_meal ? meal_path(next_meal) : meals_path)
    else
      redirect_to(policy(Meal).index? ? meals_path : root_path)
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
