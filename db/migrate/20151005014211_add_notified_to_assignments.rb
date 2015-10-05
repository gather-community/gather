class AddNotifiedToAssignments < ActiveRecord::Migration
  def change
    add_column :assignments, :notified, :boolean, null: false, default: false
    add_index :assignments, :notified
  end
end
