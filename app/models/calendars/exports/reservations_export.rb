# frozen_string_literal: true

module Calendars
  module Exports
    # Abstract parent class for reservation calendars of various sorts
    class ReservationsExport < Export
      # If all of these are the same for any N reservations, we should group them together in the export.
      GROUP_ATTRIBS = %w[starts_at ends_at reserver_id meal_id name].freeze

      def kind_name(_object)
        "Reservation"
      end

      protected

      def base_scope
        # resource_id sort is for specs
        Reservations::ReservationPolicy::Scope.new(user, Reservations::Reservation).resolve
          .joins(:resource, :reserver).includes(:resource, :reserver)
          .with_max_age(MAX_EVENT_AGE).oldest_first.order(:resource_id)
      end

      def events_for_objects(reservations)
        groups = reservations.group_by { |r| r.attributes.slice(*GROUP_ATTRIBS) }
        groups.map do |_, members|
          Event.new(basic_event_attribs(members[0]).merge(
            location: members.map(&:location_name).join(" + ")
          ))
        end
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
