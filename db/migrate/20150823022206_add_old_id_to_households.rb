class AddOldIdToHouseholds < ActiveRecord::Migration[4.2]
  def change
    unless column_exists?(:households, :old_id)
      add_column :households, :old_id, :integer
    end
  end
end
