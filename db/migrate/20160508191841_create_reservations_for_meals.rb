# frozen_string_literal: true

class CreateReservationsForMeals < ActiveRecord::Migration[4.2]
  def up
    Meal.transaction do
      Meal.where(reservation_id: nil).find_each do |m|
        puts "Creating reservation for meal #{m.id}"
        m.build_reservations
        m.save!
      end
    end
  end
end
