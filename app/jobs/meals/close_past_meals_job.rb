# frozen_string_literal: true

module Meals
  # Closes past meals after a certain delay period.
  class ClosePastMealsJob < ApplicationJob
    def perform
      ActsAsTenant.without_tenant do
        Meal.open.with_min_age(Settings.meals.close_cutoff_age.hours).each(&:close!)
      end
    end
  end
end
