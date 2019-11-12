# frozen_string_literal: true

# Closes past meals after a certain delay period.
module Meals
  class ClosePastMealsJob < ApplicationJob
    def perform
      ActsAsTenant.without_tenant do
        Meal.open.with_min_age(Settings.meals.close_cutoff_age.hours).each { |m| m.close! }
      end
    end
  end
end
