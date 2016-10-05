class RemoveCostColumnsFromMeals < ActiveRecord::Migration
  def up
    remove_column :meals, :ingredient_cost
    remove_column :meals, :pantry_cost
  end
end
