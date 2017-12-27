class AddNotifiedToSignups < ActiveRecord::Migration[4.2]
  def change
    add_column :signups, :notified, :boolean, null: false, default: false
    add_index :signups, :notified
  end
end
