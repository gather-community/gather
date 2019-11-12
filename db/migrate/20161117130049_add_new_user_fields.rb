# frozen_string_literal: true

class AddNewUserFields < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :birthdate, :date, index: true
    add_column :users, :joined_on, :date, index: true
    add_column :users, :emergency_contacts, :text
  end
end
