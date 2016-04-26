class AddDateIndexToReservations < ActiveRecord::Migration
  def change
    add_index :reservations, :starts_at
  end
end
