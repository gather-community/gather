class AddOldIdToHouseholds < ActiveRecord::Migration
  def change
    add_column :households, :old_id, :integer
  end
end
