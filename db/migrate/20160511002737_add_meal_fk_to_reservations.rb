class AddMealFkToReservations < ActiveRecord::Migration[4.2]
  def up
    add_reference :reservations, :meal, foreign_key: true, index: true
    execute("UPDATE reservations SET meal_id = (SELECT id FROM meals WHERE reservation_id = reservations.id)")
  end
end
