# frozen_string_literal: true

module Reservations
  module Rules
    # Models a set of Rules governing a single reservation.
    # Represents the unification of one or more protocols.
    class RuleSet
      include ActiveModel::SerializerSupport

      # Finds all matching protocols and unions them into one.
      # Raises an error if any two protocols have non-nil values for the same attrib.
      def self.build_for(reservation)
        protocols = Protocol.matching(reservation.resource, reservation.kind)
        rules = {}
        Rule::NAMES.each do |rule_name|
          filtered_protocols = protocols.select { |p| p[rule_name].present? }
          next if filtered_protocols.empty?
          klass = Rule.class_for(rule_name)
          rules[rule_name] = klass.new(
            value: klass.aggregate(filtered_protocols.map(&rule_name)),
            community: reservation.community,
            resources: filtered_protocols.flat_map(&:resources).uniq
          )
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
        if other_communities? && other_communities_rule.community != reservation.reserver_community
          other_communities
        else
          "ok"
        end
      end

      Rule::NAMES.each do |rule_name|
        define_method(:"#{rule_name}_rule") do
          rules[rule_name]
        end

        define_method(rule_name) do
          rules[rule_name]&.value
        end

        define_method(:"#{rule_name}?") do
          !rules[rule_name].nil?
        end
      end

      def to_s
        rules.map(&:to_s).join("\n")
      end

      private

      attr_accessor :reservation, :rules
    end
  end
end
