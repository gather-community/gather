# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_formula_roles
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  formula_id :bigint           not null
#  role_id    :bigint           not null
#  updated_at :datetime         not null
#
module Meals
  # Join model between Formula and Role
  class FormulaRole < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :formula, class_name: "Meals::Formula", inverse_of: :formula_roles
    belongs_to :role, class_name: "Meals::Role"
  end
end
