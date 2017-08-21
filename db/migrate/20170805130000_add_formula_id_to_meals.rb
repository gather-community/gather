class AddFormulaIdToMeals < ActiveRecord::Migration
  def change
    add_column :meals, :formula_id, :integer
    add_index :meals, :formula_id
    add_foreign_key :meals, :meals_formulas, column: :formula_id
  end
end
