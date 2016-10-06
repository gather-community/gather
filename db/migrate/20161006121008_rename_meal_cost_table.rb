class RenameMealCostTable < ActiveRecord::Migration
  def change
    rename_table :meal_costs, :meals_costs
  end
end
