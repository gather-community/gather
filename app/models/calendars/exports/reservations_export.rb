# frozen_string_literal: true

module Calendars
  module Exports
    # Abstract parent class for reservation calendars of various sorts
    class ReservationsExport < Export
      def kind_name
        "Reservation"
      end

      protected

      def base_scope
        Reservations::ReservationPolicy::Scope.new(user, Reservations::Reservation).resolve
          .includes(:resource, :reserver)
          .with_max_age(MAX_EVENT_AGE).oldest_first
      end

      def summary(reservation)
        reservation.name << (reservation.meal? ? "" : " (#{reservation.reserver_name})")
      end

      def url(reservation)
        url_for(reservation, :reservation_url)
      end
    end
  end
end
