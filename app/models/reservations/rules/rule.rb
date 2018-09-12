# frozen_string_literal: true

module Reservations
  module Rules
    # Models a single reservation rule, such as max_minutes_per_year = 200.
    class Rule
      attr_accessor :value, :resources, :kinds, :community

      NAMES = %i[fixed_start_time fixed_end_time max_lead_days
                 max_length_minutes max_minutes_per_year max_days_per_year
                 other_communities requires_kind pre_notice].freeze

      def self.class_for(rule_name)
        "Reservations::Rules::#{rule_name.to_s.camelize}Rule".constantize
      end

      def initialize(value: nil, resources: nil, community: nil, kinds: nil)
        self.value = value
        self.resources = resources
        self.kinds = kinds
        self.community = community
      end

      def name
        self.class.name.split("::").last.underscore.sub(/_rule$/, "").to_sym
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
    end
  end
end
