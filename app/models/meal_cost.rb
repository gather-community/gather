# Saves the calculated cost of a meal for future analysis.
class MealCost < ActiveRecord::Base
  belongs_to :meal, inverse_of: :meal_cost
end
