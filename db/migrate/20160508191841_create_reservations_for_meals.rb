class CreateReservationsForMeals < ActiveRecord::Migration
  def up
    Meal.transaction do
      Meal.where("reservation_id IS NULL").find_each do |m|
        puts "Creating reservation for meal #{m.id}"
        m.build_reservations
        m.save!
      end
    end
  end
end
