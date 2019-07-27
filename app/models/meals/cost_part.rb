# frozen_string_literal: true

module Meals
  # Joins a meal cost object to its constituent meal types.
  class CostPart < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :type
    belongs_to :cost, inverse_of: :parts

    # Sorts by rank of the associated meal_formula_part
    def self.by_rank
      joins(cost: :meal)
        .joins("LEFT JOIN meal_formula_parts ON meal_formula_parts.formula_id = meals.formula_id
          AND meal_formula_parts.type_id = meal_cost_parts.type_id")
        .order("meal_formula_parts.rank")
    end
  end
end
