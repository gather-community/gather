class RemoveResourceIdFromMeals < ActiveRecord::Migration
  def change
    remove_column :meals, :resource_id, :integer
  end
end
