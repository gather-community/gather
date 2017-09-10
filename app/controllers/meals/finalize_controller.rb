module Meals
  class FinalizeController < ApplicationController
    helper_method :signups
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
        if params[:confirmed] == "0"
          flash.now[:notice] = "The meal was not finalized. You can edit it below and try again, "\
             "or click 'Cancel' below to return to the meals page."
          render(:new)
        else
          # Run the save and signup in a transaction in case
          # the finalize operation fails or we need to confirm.
          Meal.transaction do
            @finalizer = Meals::Finalizer.new(@meal)

            if params[:confirmed] == "1"
              @finalizer.finalize!
              @meal.save!
              flash[:success] = "Meal finalized successfully"
              redirect_to(meals_path(finalizable: 1))
            else
              @calculator = @finalizer.calculator
              @cost = @meal.cost
              flash.now[:alert] = "<strong>Note:</strong> This meal has not been finalized yet.
                Please review and confirm your entries below.
                This information cannot be changed once confirmed, so be careful.".html_safe
              render(:confirm)
            end
          end
        end
      else
        set_validation_error_notice(@meal)
        render(:new)
      end
    end

    def signups
      @signups ||= @meal.signups.map(&:decorate)
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
