class MakePantryColsNullFalse < ActiveRecord::Migration[4.2]
  def change
    change_column_null :meal_formulas, :pantry_calc_type, false
    change_column_null :meal_formulas, :pantry_fee, false
  end
end
