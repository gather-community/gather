# frozen_string_literal: true

class AddNameToMealFormulas < ActiveRecord::Migration[4.2]
  def change
    add_column :meal_formulas, :name, :string
    execute("UPDATE meal_formulas SET name = 'Standard'")
    change_column_null :meal_formulas, :name, false
  end
end
