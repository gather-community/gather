class SignupsController < ApplicationController
  load_and_authorize_resource

  def create
    @signup.save_or_destroy!
    redirect_after_save
  end

  def update
    @signup.assign_attributes(signup_params)
    @signup.save_or_destroy!
    redirect_after_save
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

  def signup_params
    permitted = params.require(:signup).permit(:meal_id, :adult_meat, :adult_veg,
      :teen, :big_kid, :little_kid, :comments)
    permitted[:household_id] = current_user.household_id
    permitted
  end
end
