class AddUserRecoverableFields < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime
    add_column :users, :encrypted_password, :string, null: false, default: ""
    add_index :users, :reset_password_token, unique: true
  end
end
