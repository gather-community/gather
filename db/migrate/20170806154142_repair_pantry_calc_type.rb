class RepairPantryCalcType < ActiveRecord::Migration
  def up
    execute("UPDATE meal_formulas SET pantry_calc_type = 'percent' WHERE pantry_calc_type != 'fixed'")
  end
end
