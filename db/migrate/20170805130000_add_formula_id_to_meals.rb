class AddFormulaIdToMeals < ActiveRecord::Migration
  def change
    add_column :meals, :formula_id, :integer
    add_index :meals, :formula_id
    add_foreign_key :meals, :meal_formulas, column: :formula_id
  end
end
