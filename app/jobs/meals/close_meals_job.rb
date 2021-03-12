# frozen_string_literal: true

module Meals
  # Closes past meals after a certain delay period.
  class CloseMealsJob < ApplicationJob
    def perform
      ActsAsTenant.without_tenant do
        Meal.open.with_min_age(Settings.meals.close_cutoff_age.hours).find_each(&:close!)
        Meal.open.with_past_auto_close_time.find_each(&:close!)
      end
    end
  end
end
