class AddUniquenessConstraints < ActiveRecord::Migration
  def change
    add_index :assignments, [:meal_id, :role, :user_id], unique: true
    add_index :communities, :abbrv, unique: true
    add_index :communities, :name, unique: true
    add_index :invitations, [:community_id, :meal_id], unique: true
    add_index :locations, :abbrv, unique: true
    add_index :locations, :name, unique: true
    add_index :signups, [:household_id, :meal_id], unique: true
    add_index :users, :email, unique: true
  end
end
