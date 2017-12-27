class AddGmailUniqueConstraint < ActiveRecord::Migration[4.2]
  def change
    add_index :users, :google_email, unique: true
  end
end
