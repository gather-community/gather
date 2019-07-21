# frozen_string_literal: true

class CreateMealFormulaParts < ActiveRecord::Migration[5.1]
  def change
    create_table :meal_formula_parts do |t|
      t.references :cluster, null: false, index: true, foreign_key: true
      t.references :formula, index: true, null: false, foreign_key: {to_table: :meal_formulas}
      t.references :type, index: true, null: false, foreign_key: {to_table: :meal_types}
      t.decimal :share, null: false, precision: 10, scale: 4
      t.decimal :portion_size, null: false, precision: 10, scale: 2

      t.timestamps
    end

    add_index :meal_formula_parts, %i[formula_id type_id], unique: true
  end
end
