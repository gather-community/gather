# Closes past meals after a certain delay period.
module Meals
  class ClosePastMealsJob
    CLOSE_CUTOFF_AGE = 2.hours

    def perform
      Meal.open.with_min_age(CLOSE_CUTOFF_AGE).each { |m| m.close! }
    end
  end
end
