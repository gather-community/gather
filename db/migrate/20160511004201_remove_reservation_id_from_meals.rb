class RemoveReservationIdFromMeals < ActiveRecord::Migration
  def change
    remove_column :meals, :reservation_id, :integer
  end
end
