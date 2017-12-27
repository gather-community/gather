class RepairPantryCalcType < ActiveRecord::Migration[4.2]
  def up
    execute("UPDATE meal_formulas SET pantry_calc_type = 'percent' WHERE pantry_calc_type != 'fixed'")
  end
end
