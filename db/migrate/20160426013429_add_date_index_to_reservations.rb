class AddDateIndexToReservations < ActiveRecord::Migration[4.2]
  def change
    add_index :reservations, :starts_at
  end
end
