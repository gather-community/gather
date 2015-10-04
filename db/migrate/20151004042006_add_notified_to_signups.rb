class AddNotifiedToSignups < ActiveRecord::Migration
  def change
    add_column :signups, :notified, :boolean, null: false, default: false
    add_index :signups, :notified
  end
end
