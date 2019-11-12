# frozen_string_literal: true

class AddUserFields < ActiveRecord::Migration[4.2]
  def change
    rename_column :users, :email, :google_email
    add_column :users, :email, :string, null: false
    add_column :users, :first_name, :string, null: false
    add_column :users, :last_name, :string, null: false
    add_column :users, :home_phone, :string
    add_column :users, :mobile_phone, :string
    add_column :users, :work_phone, :string
    add_column :users, :household_id, :integer, null: false
  end
end
