# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_cost_parts
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint           not null
#  cost_id    :bigint           not null
#  created_at :datetime         not null
#  type_id    :bigint           not null
#  updated_at :datetime         not null
#  value      :decimal(10, 2)
#
module Meals
  # Joins a meal cost object to its constituent meal types.
  class CostPart < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :type
    belongs_to :cost, inverse_of: :parts

    # Sorts by rank of the associated meal_formula_part
    def self.by_rank
      joins(cost: :meal)
        .joins(Arel.sql("LEFT JOIN meal_formula_parts ON meal_formula_parts.formula_id = meals.formula_id
          AND meal_formula_parts.type_id = meal_cost_parts.type_id"))
        .order(FormulaPart.arel_table[:rank])
    end
  end
end
