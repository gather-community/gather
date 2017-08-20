class AddNameToMealFormulas < ActiveRecord::Migration
  def change
    add_column :meal_formulas, :name, :string
    execute("UPDATE meal_formulas SET name = 'Standard'")
    change_column_null :meal_formulas, :name, false
  end
end
