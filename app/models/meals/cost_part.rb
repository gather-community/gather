# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meal_cost_parts
#
#  id         :bigint           not null, primary key
#  value      :decimal(10, 2)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#  cost_id    :bigint           not null
#  type_id    :bigint           not null
#
# Indexes
#
#  index_meal_cost_parts_on_cluster_id           (cluster_id)
#  index_meal_cost_parts_on_cost_id              (cost_id)
#  index_meal_cost_parts_on_type_id              (type_id)
#  index_meal_cost_parts_on_type_id_and_cost_id  (type_id,cost_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (cost_id => meal_costs.id)
#  fk_rails_...  (type_id => meal_types.id)
#
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
