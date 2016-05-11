# Handles creation and updating of reservations associated with meals.
module Reservation
  class MealReservationHandler
    include ActionView::Helpers::TextHelper

    attr_accessor :meal

    def initialize(meal)
      self.meal = meal
    end

    # Creates/updates the reservation associated with the meal
    def sync
      starts_at = meal.served_at - Settings.meal_reservation_default_prep_time.minutes
      ends_at = starts_at + Settings.meal_reservation_default_length.minutes
      prefix = "Meal:"
      title = truncate(meal.title_or_no_title,
        length: ::Reservation::Reservation::NAME_MAX_LENGTH - prefix.size - 1, escape: false)

      meal.reservations.destroy_all

      meal.resources.each do |resource|
        attribs = {
          resource: resource,
          reserver: meal.creator,
          name: "#{prefix} #{title}",
          kind: "_meal",
          starts_at: starts_at,
          ends_at: ends_at,
          guidelines_ok: "1"
        }

        meal.reservations.build(attribs)
      end
    end

    # Validates the reservation and copies errors to meal.
    # Assumes reservation has been setup already.
    def validate
      meal.reservations.each do |reservation|
        unless reservation.valid?
          errors = reservation.errors.map do |attrib, msg|
            if attrib == :base
              msg
            else
              "#{Reservation.human_attribute_name(attrib)}: #{msg}"
            end
          end.join(", ")
          meal.errors.add(:base,
            "The following error(s) occurred in making a #{reservation.resource_full_name} reservation "\
            "for this meal: #{errors}.")
        end
      end
    end
  end
end
