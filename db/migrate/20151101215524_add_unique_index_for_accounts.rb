# frozen_string_literal: true

class AddUniqueIndexForAccounts < ActiveRecord::Migration[4.2]
  def change
    add_index :accounts, %i[community_id household_id], unique: true
  end
end
