class SignupsController < ApplicationController
  load_and_authorize_resource

  def create
    @signup.save!
    redirect_to meals_path
  end

  def update
    @signup.update_attributes!(signup_params)
    redirect_to meals_path
  end

  private

  def signup_params
    permitted = params.require(:signup).permit(:meal_id, :adult_meat, :adult_veg,
      :teen, :big_kid, :little_kid, :comments)
    permitted[:household_id] = current_user.household_id
    permitted
  end
end
