class MealsController < ApplicationController
  load_and_authorize_resource

  def new
    @meal = Meal.new_with_defaults
    @min_date = Date.today.strftime("%Y-%m-%d")
    @active_users = User.by_name.active
  end

  private

  def meal_params
    permitted = [:email, :first_name, :last_name, :mobile_phone, :home_phone, :work_phone]
    permitted += [:admin, :google_email, :household_id] if can?(:manage, Meal)
    params.require(:meal).permit(permitted)
  end
end
