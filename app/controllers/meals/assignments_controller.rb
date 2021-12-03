# frozen_string_literal: true

module Meals
  # Work assignments for meals. Reached via AJAX. Renders the household worker form.
  class AssignmentsController < ApplicationController
    before_action -> { nav_context(:meals) }

    decorates_assigned :meal

    def destroy
      @assignment = Assignment.find(params[:id])
      authorize(@assignment)
      @assignment.destroy
      render_form
    end

    private

    def render_form
      @meal = @assignment.meal
      @household_workers = Meals::HouseholdWorkersPresenter.new(@meal, current_user.household)
      render(partial: "meals/meals/household_worker_form")
    end
  end
end
