class AddOldIdToHouseholds < ActiveRecord::Migration
  def change
    unless column_exists?(:households, :old_id)
      add_column :households, :old_id, :integer
    end
  end
end
