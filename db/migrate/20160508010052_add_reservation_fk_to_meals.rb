class AddReservationFkToMeals < ActiveRecord::Migration[4.2]
  def up
    add_reference :meals, :reservation, index: true, foreign_key: true
  end
end
