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
      prefix = "Meal:"
      title = truncate(meal.title_or_no_title,
        length: ::Reservation::Reservation::NAME_MAX_LENGTH - prefix.size - 1, escape: false)

      meal.reservations.destroy_all

      meal.resourcings.each do |resourcing|
        attribs = {
          resource: resourcing.resource,
          reserver: meal.creator,
          name: "#{prefix} #{title}",
          kind: "_meal",
          starts_at: starts_at = meal.served_at - resourcing.prep_time.minutes,
          ends_at: starts_at + resourcing.total_time.minutes,
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

    private

    def settings
      @settings ||= meal.host_community.settings.reservations.meals
    end
  end
end
