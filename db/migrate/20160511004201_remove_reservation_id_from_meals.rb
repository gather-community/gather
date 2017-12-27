class RemoveReservationIdFromMeals < ActiveRecord::Migration[4.2]
  def change
    remove_column :meals, :reservation_id, :integer
  end
end
