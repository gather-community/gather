class RemoveMealHostableFromResources < ActiveRecord::Migration[4.2]
  def change
    remove_column :resources, :meal_hostable, :boolean
  end
end
