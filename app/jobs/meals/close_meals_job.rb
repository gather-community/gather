# frozen_string_literal: true

module Meals
  # Closes past meals after a certain delay period.
  class CloseMealsJob < ApplicationJob
    def perform
      ActsAsTenant.without_tenant do
        Meal.open.with_min_age(Settings.meals.close_cutoff_age.hours).find_each { |m| close_meal(m) }
        Meal.open.with_past_auto_close_time.find_each { |m| close_meal(m) }
      end
    end

    private

    def close_meal(meal)
      # We have to set the tenant in case associated records get created by listeners.
      ActsAsTenant.with_tenant(meal.cluster) do
        meal.close!
      end
    end
  end
end
