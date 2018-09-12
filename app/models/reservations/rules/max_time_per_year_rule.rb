# frozen_string_literal: true

module Reservations
  module Rules
    # Rule for limiting time reservered per year. Abstract class.
    class MaxTimePerYearRule < Rule
      def check(reservation)
        booked = booked_time_for_year(reservation, unit)
        if booked + reservation.send(unit) > value
          msg = I18n.t("reservations/protocol.exceeded_time",
            kind_resource: kind_resource_str, max: interval(value), booked: interval(booked)).gsub("  ", " ")
          [:base, msg]
        else
          true
        end
      end

      private

      # Gets the amount of time that the given reservation's reserver household has booked
      # on the current rule's resources in the reservation's year, in the given unit (:hours or :minutes).
      # The number of days is rounded up for each event.
      # i.e., a 1-hour event and a 10-hour event both counts as 1 day, while a 36-hour event
      # counts as 2 days.
      def booked_time_for_year(reservation, unit)
        year = reservation.starts_at.year
        Reservation
          .where(resources.present? ? {resource: resources} : nil)
          .where(kinds.present? ? {kind: kinds} : nil)
          .where(reserver: reservation.household_users)
          .where(starts_at: Time.zone.local(year)...Time.zone.local(year + 1))
          .to_a.sum(&unit)
      end

      def kind_resource_str
        kind_str = (kinds || []).join("/").presence
        resource_str = (resources&.map(&:name) || []).join("/").presence
        joined = [kind_str, resource_str].compact.join(" ")
        joined.blank? ? "" : "#{joined} "
      end
    end
  end
end
