class AddMealReferenceToReservations < ActiveRecord::Migration
  def change
    add_reference :reservations, :meal, index: true, foreign_key: true
  end
end
