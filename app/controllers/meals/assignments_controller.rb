# frozen_string_literal: true

module Meals
  # Work assignments for meals. Reached via AJAX. Renders the household worker form.
  class AssignmentsController < ApplicationController
    before_action -> { nav_context(:meals) }

    decorates_assigned :meal

    def destroy
      @assignment = Assignment.find(params[:id])
      authorize(@assignment)
      @worker_change_notifier = WorkerChangeNotifier.new(current_user, @assignment.meal)
      @assignment.destroy
      @worker_change_notifier.check_and_send!
      render_form
    end

    private

    def render_form
      @meal = @assignment.meal
      @household_workers = Meals::HouseholdWorkersPresenter.new(@meal.reload, current_user.household)
      render(partial: "meals/meals/household_worker_form")
    end
  end
end
