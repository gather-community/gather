# frozen_string_literal: true

module Reservations
  # Handles creation and updating of reservations associated with meals.
  class MealReservationHandler
    include ActionView::Helpers::TextHelper

    attr_accessor :meal

    def initialize(meal)
      self.meal = meal
    end

    # Builds the reservation associated with the meal. Deletes any previous reservations.
    # Builds, not creates, because we want to see if validation passes first.
    def build_reservations
      current_reservations = []
      meal.resourcings.each do |resourcing|
        reservation = meal.reservations.detect { |r| r.resource == resourcing.resource }
        # Don't adjust existing reservations unless something important has changed.
        if reservation.nil? || meal_dirty?
          reservation ||= meal.reservations.build(resource: resourcing.resource)
          reservation.assign_attributes(reservation_attributes(resourcing))
        end
        current_reservations << reservation
      end
      meal.reservations.destroy(*(meal.reservations - current_reservations))
    end

    # Validates the reservation and copies errors to meal.
    # Assumes build_reservations has been run already.
    def validate_meal
      meal.reservations.each do |reservation|
        next if reservation.valid?
        errors = reservation.errors.map do |attrib, msg|
          attrib == :base ? msg : "#{Reservation.human_attribute_name(attrib)}: #{msg}"
        end.join(", ")
        meal.errors.add(:base,
                        "The following error(s) occurred in making a #{reservation.resource_name} reservation "\
                        "for this meal: #{errors}.")
      end
    end

    # Validates that changes to the reservation are valid with respect to the meal.
    def validate_reservation(reservation)
      return if meal.served_at.nil?
      if reservation.starts_at&.>(meal.served_at)
        reservation.errors.add(:starts_at, :after_meal_time, time: meal_time)
      elsif reservation.ends_at&.<(meal.served_at)
        reservation.errors.add(:ends_at, :before_meal_time, time: meal_time)
      end
    end

    # Updates the Resourcing associated with the reservation to reflect the new reservation times.
    # Assumes that validate_reservation has been called already and the changes are valid.
    def sync_resourcings(reservation)
      resourcing = meal.resourcings.detect { |r| r.resource == reservation.resource }
      raise ArgumentError, "Meal is not associated with resource" if resourcing.nil?
      resourcing.update(
        prep_time: (meal.served_at - reservation.starts_at) / 1.minute,
        total_time: (reservation.ends_at - reservation.starts_at) / 1.minute
      )
    end

    private

    def reservation_attributes(resourcing)
      starts_at = meal.served_at - resourcing.prep_time.minutes
      {
        reserver: meal.creator,
        name: reservation_name,
        kind: "_meal",
        starts_at: starts_at,
        ends_at: starts_at + resourcing.total_time.minutes,
        guidelines_ok: "1"
      }
    end

    def meal_dirty?
      @meal_dirty ||= meal.new_record? || meal.will_save_change_to_served_at? ||
        meal.will_save_change_to_title?
    end

    def reservation_name
      prefix = "Meal:"
      title = truncate(meal.decorate.title_or_no_title,
                       length: Reservation::NAME_MAX_LENGTH - prefix.size - 1, escape: false)
      "#{prefix} #{title}"
    end

    def settings
      @settings ||= meal.community.settings.reservations.meals
    end

    def meal_time
      I18n.l(meal.served_at, format: :time_only)
    end
  end
end
