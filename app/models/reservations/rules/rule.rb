# frozen_string_literal: true

module Reservations
  module Rules
    # Models a single reservation rule, such as max_minutes_per_year = 200.
    class Rule
      attr_accessor :name, :value, :resources, :community

      NAMES = %i[fixed_start_time fixed_end_time max_lead_days
                 max_length_minutes max_minutes_per_year max_days_per_year
                 other_communities requires_kind pre_notice].freeze

      def self.class_for(rule_name)
        "Reservations::Rules::#{rule_name.to_s.camelize}Rule".constantize
      end

      def initialize(value: nil, resources: nil, community: nil)
        self.value = value
        self.resources = resources
        self.community = community
      end

      # Abstract method.
      # Returns true if reservation passes the check (conforms to the rule).
      # Returns a 2-element array for AR errors.add if not.
      def check(_reservation)
        raise NotImplementedError
      end

      def to_s
        "#{self.class.name}: #{value}"
      end

      protected

      # Gets the amount of time that the given reservation's reserver household has booked
      # on the current rule's resources in the reservation's year, in the given unit (:hours or :seconds).
      def booked_time_for_year(reservation, unit)
        year = reservation.starts_at.year
        Reservation.booked_time_for(
          resources: resources,
          household: reservation.household,
          period: Time.zone.local(year)...Time.zone.local(year + 1),
          unit: unit
        )
      end
    end
  end
end
