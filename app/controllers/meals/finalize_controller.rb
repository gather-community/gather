module Meals
  class FinalizeController < ApplicationController
    before_action -> { nav_context(:meals, :meals) }

    def new
      @meal = Meal.find(params[:meal_id])
      authorize @meal, :finalize?
      @meal.build_cost
      @dupes = []
    end

    def create
      @meal = Meal.find(params[:meal_id])
      authorize @meal, :finalize?

      # We assign finalized here so that the meal/signup validations don't complain about no spots left.
      @meal.assign_attributes(finalize_params.merge(status: "finalized"))

      if (@dupes = @meal.duplicate_signups).any?
        flash.now[:error] = "There are duplicate signups. "\
          "Please correct by adding numbers for each diner type."
        render(:new)
      elsif @meal.valid?
        # Run the save and signup in a transaction in case the finalize operation fails.
        # Save the meal first so that any signups marked for deletion are deleted.
        Meal.transaction do
          @meal.save!
          Meals::Finalizer.new(@meal).finalize!
        end
        flash[:success] = "Meal finalized successfully"
        redirect_to(meals_path(finalizable: 1))
      else
        set_validation_error_notice
        render(:new)
      end
    end

    private
    
    def finalize_params
      params.require(:meal).permit(
        signups_attributes: [:id, :household_id, :_destroy] + Signup::SIGNUP_TYPES,
        cost_attributes: [:ingredient_cost, :pantry_cost, :payment_method]
      )
    end
  end
end
