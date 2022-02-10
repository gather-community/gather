# frozen_string_literal: true

class AddTakeoutToMealSignups < ActiveRecord::Migration[6.0]
  def change
    add_column :meal_signups, :takeout, :boolean, default: false, null: false
  end
end
