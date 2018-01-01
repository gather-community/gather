class AddPantryReimbursementToMealFormulas < ActiveRecord::Migration[5.1]
  def change
    add_column :meal_formulas, :pantry_reimbursement, :boolean, default: false
    execute("UPDATE meal_formulas SET pantry_reimbursement = 't'")
  end
end
