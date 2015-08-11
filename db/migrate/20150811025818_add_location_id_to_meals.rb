class AddLocationIdToMeals < ActiveRecord::Migration
  def change
    add_reference :meals, :location, index: true, foreign_key: true
    loc = Location.first
    raise "No locations available" if loc.nil?
    Meal.all.each{ |m| m.update_attribute(:location_id, loc.id) }
    change_column_null :meals, :location_id, true
  end
end
