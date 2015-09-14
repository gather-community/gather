class AddDeactivatedAtToHouseholds < ActiveRecord::Migration
  def change
    add_column :households, :deactivated_at, :datetime
    add_index :households, :deactivated_at
  end
end
