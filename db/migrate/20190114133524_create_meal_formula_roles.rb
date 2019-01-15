# frozen_string_literal: true

class CreateMealFormulaRoles < ActiveRecord::Migration[5.1]
  def change
    create_table :meal_formula_roles do |t|
      t.references :formula, null: false, index: true, foreign_key: {to_table: :meal_formulas}
      t.references :role, null: false, index: true, foreign_key: {to_table: :meal_roles}

      t.timestamps
    end
  end
end
