class AddNewUserFields < ActiveRecord::Migration
  def change
    add_column :users, :birthdate, :date, index: true
    add_column :users, :joined_on, :date, index: true
    add_column :users, :emergency_contacts, :jsonb
  end
end
