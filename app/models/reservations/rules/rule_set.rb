# frozen_string_literal: true

module Reservations
  module Rules
    # Models a set of Rules governing a single reservation.
    # Represents the unification of one or more protocols.
    # Knows how to aggregate multiple rules where necessary.
    class RuleSet
      # Finds all matching protocols and unions them into one.
      # Raises an error if any two protocols have non-nil values for the same attrib.
      def self.build_for(resource:, kind:)
        rules = []
        Protocol.matching(resource, kind).each do |protocol|
          Rule::NAMES.each do |rule_name|
            klass = Rule.class_for(rule_name)
            next if (value = protocol.send(rule_name)).blank?
            rules << klass.new(value: value, community: resource.community, kinds: protocol.kinds,
                               resources: protocol.resources)
          end
        end
        new(resource: resource, kind: kind, rules: rules)
      end

      def initialize(resource:, kind:, rules:)
        self.resource = resource
        self.kind = kind
        self.rules = rules
      end

      # Runs `check` on each rule for the given reservation and returns any error info.
      def errors(reservation)
        rules.map { |r| r.check(reservation) }.reject { |v| v == true }
      end

      # Returns one of [ok, read_only, sponsor, forbidden] to describe the access level of
      # the given reserver vis a vis the rule set's resource.
      def access_level(reserver_community)
        return "ok" if resource_community == reserver_community
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

      def rules_with_name(name)
        rules_by_name[name] || []
      end

      # Returns whether any rule in the set has requires_kind == true.
      def requires_kind?
        rules_by_name[:requires_kind].present?
      end

      %i[fixed_start_time fixed_end_time].each do |method|
        define_method(:"#{method}?") do
          !send(method).nil?
        end
      end

      def to_s
        rules.map(&:to_s).join("\n")
      end

      private

      attr_accessor :resource, :kind, :rules
      delegate :community, to: :resource, prefix: true

      def values_for(rule_name)
        rules_by_name[rule_name]&.map(&:value) || []
      end

      def rules_by_name
        @rules_by_name ||= rules.group_by(&:name)
      end
    end
  end
end
