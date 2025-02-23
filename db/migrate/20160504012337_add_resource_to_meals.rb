# frozen_string_literal: true

class AddResourceToMeals < ActiveRecord::Migration[4.2]
  ID_MAP = {
    1 => 5,
    2 => 11,
    3 => 16,
    4 => 15
  }.freeze

  def up
    add_reference :meals, :resource, index: true, foreign_key: true
    Meal.find_each do |meal|
      raise "no match" unless ID_MAP[meal.location_id]

      meal.update_attribute(:resource_id, ID_MAP[meal.location_id])
    end
    change_column_null :meals, :resource_id, false
    remove_column :meals, :location_id
  end
end
