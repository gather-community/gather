# frozen_string_literal: true

class AddClusterToMealFormulaRoles < ActiveRecord::Migration[6.0]
  def change
    add_column :meal_formula_roles, :cluster_id, :bigint
    query = "UPDATE meal_formula_roles SET cluster_id =
      (SELECT cluster_id FROM meal_formulas WHERE meal_formulas.id = meal_formula_roles.formula_id)"
    reversible do |dir|
      dir.up { execute(query) }
    end
    change_column_null :meal_formula_roles, :cluster_id, false
    add_index :meal_formula_roles, :cluster_id
    add_foreign_key :meal_formula_roles, :clusters
  end
end
