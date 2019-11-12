# frozen_string_literal: true

class AddMoreToUsersAndHouseholds < ActiveRecord::Migration[4.2]
  def change
    add_column :households, :vehicles, :text
    add_column :households, :emergency_contacts, :text
    add_column :households, :garages, :string
    add_column :users, :preferred_contact, :string
    remove_column :users, :emergency_contacts, :text
  end
end
