# frozen_string_literal: true

module Reservations
  module Rules
    # Models a set of Rules governing a single reservation.
    # Represents the unification of one or more protocols.
    # Knows how to aggregate multiple rules where necessary.
    class RuleSet
      include ActiveModel::SerializerSupport

      # Finds all matching protocols and unions them into one.
      # Raises an error if any two protocols have non-nil values for the same attrib.
      def self.build_for(reservation)
        rules = []
        Protocol.matching(reservation.resource, reservation.kind).each do |protocol|
          Rule::NAMES.each do |rule_name|
            klass = Rule.class_for(rule_name)
            next unless (value = protocol.send(rule_name)).present?
            rules << klass.new(
              value: value,
              community: reservation.community,
              resources: protocol.resources
            )
          end
        end
        new(reservation: reservation, rules: rules)
      end

      def initialize(reservation:, rules:)
        self.reservation = reservation
        self.rules = rules
      end

      # Runs `check` on each rule for the given reservation and returns any error info.
      def errors(reservation)
        rules.map { |r| r.check(reservation) }.reject { |v| v == true }
      end

      # Returns one of [ok, read_only, sponsor, forbidden] to describe the access level of the current
      # reservation's reserver vis a vis the resource.
      def access_level
        return "ok" if reservation_community == reserver_community
        ranks = OtherCommunitiesRule::VALUES
        values_for(:other_communities).max_by { |v| ranks.index(v.to_sym) } || "ok"
      end

      # Returns the first fixed_start_time encountered in the rule set, or nil if none exist.
      def fixed_start_time
        values_for(:fixed_start_time).first
      end

      # Returns the first fixed_end_time encountered in the rule set, or nil if none exist.
      def fixed_end_time
        values_for(:fixed_end_time).first
      end

      # Returns all pre-notices encountered in the rule set joined together, or nil if none exist.
      def pre_notice
        values_for(:pre_notice).join("\n\n").presence
      end

      # Returns whether any rule in the set has requires_kind == true.
      def requires_kind?
        rules_by_type[:requires_kind].present?
      end

      %i[fixed_start_time fixed_end_time pre_notice].each do |method|
        define_method(:"#{method}?") do
          !send(method).nil?
        end
      end

      def to_s
        rules.map(&:to_s).join("\n")
      end

      private

      attr_accessor :reservation, :rules
      delegate :community, to: :reservation, prefix: true
      delegate :reserver_community, to: :reservation

      def values_for(rule_name)
        rules_by_type[rule_name]&.map(&:value) || []
      end

      def rules_by_type
        @rules_by_type ||= rules.group_by(&:name)
      end
    end
  end
end
