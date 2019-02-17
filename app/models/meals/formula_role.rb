# frozen_string_literal: true

module Meals
  # Join model between Formula and Role
  class FormulaRole < ApplicationRecord
    belongs_to :formula, class_name: "Meals::Formula", inverse_of: :formula_roles
    belongs_to :role, class_name: "Meals::Role"
  end
end
