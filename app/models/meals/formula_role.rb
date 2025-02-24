# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meal_formula_roles
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#  formula_id :bigint           not null
#  role_id    :bigint           not null
#
# Indexes
#
#  index_meal_formula_roles_on_cluster_id  (cluster_id)
#  index_meal_formula_roles_on_formula_id  (formula_id)
#  index_meal_formula_roles_on_role_id     (role_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (formula_id => meal_formulas.id)
#  fk_rails_...  (role_id => meal_roles.id)
#
  # Join model between Formula and Role
  class FormulaRole < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :formula, class_name: "Meals::Formula", inverse_of: :formula_roles
    belongs_to :role, class_name: "Meals::Role"
  end
end
