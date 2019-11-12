# frozen_string_literal: true

class AddUniquenessConstraints < ActiveRecord::Migration[4.2]
  def change
    add_index :assignments, %i[meal_id role user_id], unique: true
    add_index :communities, :abbrv, unique: true
    add_index :communities, :name, unique: true
    add_index :invitations, %i[community_id meal_id], unique: true
    add_index :locations, :abbrv, unique: true
    add_index :locations, :name, unique: true
    add_index :signups, %i[household_id meal_id], unique: true
    add_index :users, :email, unique: true
  end
end
