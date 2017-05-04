# Closes past meals after a certain delay period.
module Meals
  class ClosePastMealsJob
    def perform
      Meal.open.with_min_age(Settings.meals.close_cutoff_age.hours).each { |m| m.close! }
    end
  end
end
