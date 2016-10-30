# Saves the calculated cost of a meal for future analysis.
module Meals
  class Cost < ActiveRecord::Base
    belongs_to :meal, inverse_of: :cost

    validates :ingredient_cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :pantry_cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :payment_method, presence: true

    def total_cost
      ingredient_cost + pantry_cost
    end
  end
end
