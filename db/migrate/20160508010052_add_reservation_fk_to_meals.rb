class AddReservationFkToMeals < ActiveRecord::Migration
  def up
    add_reference :meals, :reservation, index: true, foreign_key: true
  end
end
