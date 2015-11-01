class AddUniqueIndexForAccounts < ActiveRecord::Migration
  def change
    add_index :accounts, [:community_id, :household_id], unique: true
  end
end
