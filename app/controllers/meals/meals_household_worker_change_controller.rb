# frozen_string_literal: true

module Meals
  class MealsHouseholdWorkerChangeController < ApplicationController
    decorates_assigned :meal

    def update
      @meal = Meal.find(params[:id])
      authorize(@meal)
      @worker_change_notifier = WorkerChangeNotifier.new(current_user, @meal)
      @meal.assign_attributes(meal_params)
      @meal.save
      render_form
    end

    protected

    def klass
      Meal
    end

    private

    # Pundit built-in helper doesn't work due to namespacing
    def meal_params
      permitted = policy(@meal).permitted_attributes
      params.require(:meals_meal).permit(permitted)
    end

    def render_form
      @household_workers = Meals::HouseholdWorkersPresenter.new(@meal, current_user.household)
      @expand_help_out_form = false
      render(partial: "meals/meals/household_worker_form")
    end
  end
end
