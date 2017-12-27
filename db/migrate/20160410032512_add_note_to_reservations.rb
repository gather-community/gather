class AddNoteToReservations < ActiveRecord::Migration[4.2]
  def change
    add_column :reservations, :note, :text
  end
end
