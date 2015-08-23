class AddUserIndicesAndFKs < ActiveRecord::Migration
  def change
    add_index :users, :household_id
    add_foreign_key :users, :households
  end
end
