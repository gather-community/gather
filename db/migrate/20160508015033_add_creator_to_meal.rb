# frozen_string_literal: true

class AddCreatorToMeal < ActiveRecord::Migration[4.2]
  def up
    add_reference :meals, :creator, index: true
    add_foreign_key :meals, :users, column: "creator_id"

    admins = {}
    Meal.find_each do |meal|
      admin = (admins[meal.community_id] ||= User.in_community(meal.community_id)
        .where(admin: true).first)
      raise "Couldn't find admin to set as creator for meal #{meal.id}" unless admin

      meal.update_attribute(:creator_id, admin.id)
    end

    change_column_null :meals, :creator_id, false
  end
end
