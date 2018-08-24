# frozen_string_literal: true

module Meals
  class FinalizeController < ApplicationController
    helper_method :signups
    before_action -> { nav_context(:meals, :meals) }
    decorates_assigned :meal

    def new
      @meal = Meal.find(params[:meal_id])
      authorize @meal, :finalize?
      @dupes = []
      build_meal_cost
      prepare_and_render_form
    end

    def create
      @meal = Meal.find(params[:meal_id])
      authorize @meal, :finalize?

      # We assign finalized here so that the meal/signup validations don't complain about no spots left.
      @meal.assign_attributes(finalize_params.merge(status: "finalized"))

      # Need to build the meal cost object so it can hold validation errors.
      build_meal_cost

      if (@dupes = @meal.duplicate_signups).any?
        flash.now[:error] = "There are duplicate signups. "\
          "Please correct by adding numbers for each diner type."
        prepare_and_render_form
      elsif @meal.valid?
        if params[:confirmed] == "0"
          flash.now[:notice] = "The meal was not finalized. You can edit it below and try again, "\
             "or click 'Cancel' below to return to the meals page."
          prepare_and_render_form
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
              prepare_and_render_form(:confirm)
            end
          end
        end
      else
        set_validation_error_notice(@meal)
        prepare_and_render_form
      end
    end

    def signups
      @signups ||= @meal.signups.map(&:decorate)
    end

    private

    def prepare_and_render_form(template = :new)
      # We rerendering form, need to set status back to closed or the policy won't let us edit stuff.
      @meal.status = "closed" if @meal.finalized?
      render(template)
    end

    def build_meal_cost
      @meal.build_cost if @meal.cost.nil?
    end

    def finalize_params
      params.require(:meal).permit(
        signups_attributes: %i[id household_id _destroy] + Signup::SIGNUP_TYPES,
        cost_attributes: %i[ingredient_cost pantry_cost payment_method]
      )
    end
  end
end
