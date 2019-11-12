# frozen_string_literal: true

class AddMealAbbrvToResources < ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :meal_abbrv, :string, limit: 6
  end
end
