class AddMealAbbrvToResources < ActiveRecord::Migration
  def change
    add_column :resources, :meal_abbrv, :string, limit: 6
  end
end
