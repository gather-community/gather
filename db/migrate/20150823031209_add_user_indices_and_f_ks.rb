# frozen_string_literal: true

class AddUserIndicesAndFKs < ActiveRecord::Migration[4.2]
  def change
    add_index :users, :household_id
    add_foreign_key :users, :households
  end
end
