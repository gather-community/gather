# Handles creation and updating of reservations associated with meals.
module Reservation
  class MealReservationHandler
    attr_accessor :meal

    def initialize(meal)
      self.meal = meal
    end

    # Creates/updates the reservation associated with the meal
    def sync
      starts_at = meal.served_at - Settings.meal_reservation_default_prep_time.minutes
      ends_at = starts_at + Settings.meal_reservation_default_length.minutes
      attribs = {
        resource: meal.resource,
        reserver: meal.creator,
        name: "Meal: #{meal.title_or_no_title}",
        kind: "_meal",
        starts_at: starts_at,
        ends_at: ends_at,
        guidelines_ok: "1"
      }

      if meal.reservation # Update
        meal.reservation.assign_attributes(attribs)
      else # Create
        meal.build_reservation(attribs)
      end
    end

    # Validates the reservation and copies errors to meal.
    # Assumes reservation has been setup already.
    def validate
      unless meal.reservation.valid?
        errors = meal.reservation.errors.map do |attrib, msg|
          if attrib == :base
            msg
          else
            "#{Reservation.human_attribute_name(attrib)}: #{msg}"
          end
        end.join(", ")
        meal.errors.add(:base,
          "The following error(s) occurred in making a reservation for this meal: #{errors}.")
      end
    end
  end
end
