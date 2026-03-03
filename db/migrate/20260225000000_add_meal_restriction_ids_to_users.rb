# frozen_string_literal: true

class AddMealRestrictionIdsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :meal_restriction_ids, :jsonb, null: false, default: []
  end
end
