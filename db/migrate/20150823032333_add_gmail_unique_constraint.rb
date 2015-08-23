class AddGmailUniqueConstraint < ActiveRecord::Migration
  def change
    add_index :users, :google_email, unique: true
  end
end
