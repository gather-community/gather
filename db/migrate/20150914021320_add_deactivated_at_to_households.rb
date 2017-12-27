class AddDeactivatedAtToHouseholds < ActiveRecord::Migration[4.2]
  def change
    add_column :households, :deactivated_at, :datetime
    add_index :households, :deactivated_at
  end
end
