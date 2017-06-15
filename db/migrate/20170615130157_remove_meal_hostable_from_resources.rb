class RemoveMealHostableFromResources < ActiveRecord::Migration
  def change
    remove_column :resources, :meal_hostable, :boolean
  end
end
