class SignupsController < ApplicationController
  include MealShowable

  load_and_authorize_resource

  def create
    # TODO force household here instead of signup_params
    if @signup.save_or_destroy
      redirect_after_save
    else
      render_meal_show
    end
  end

  def update
    # TODO force household here instead of signup_params
    @signup.assign_attributes(signup_params)
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
      redirect_to(meals_path)
    end
  end

  def render_meal_show
    @meal = @signup.meal
    @signups = @meal.signups.includes(household: :community).sorted
    authorize!(:show, @meal)
    load_prev_next_meal # From MealShowable
    render("meals/show")
  end

  def signup_params
    permitted = params.require(:signup).permit(Signup::SIGNUP_TYPES + [:meal_id, :comments])
    permitted[:household_id] = current_user.household_id
    permitted
  end
end
