class AddIndexForDeactivatedAt < ActiveRecord::Migration
  def change
    add_index :users, :deactivated_at
  end
end
