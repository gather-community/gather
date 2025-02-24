# frozen_string_literal: true

module Calendars
  module Rules
    # Models a set of Rules governing a single event.
    # Represents the unification of one or more protocols.
    # Knows how to aggregate multiple rules where necessary.
    class RuleSet
      extend ActiveModel::Naming

      # Finds all matching protocols and unions them into one.
      # Raises an error if any two protocols have non-nil values for the same attrib.
      def self.build_for(calendar:, kind:)
        rules = []
        Protocol.matching(calendar, kind).each do |protocol|
          Rule::NAMES.each do |rule_name|
            klass = Rule.class_for(rule_name)
            next if (value = protocol.send(rule_name)).blank?

            rules << klass.new(value: value, community: calendar.community, kinds: protocol.kinds,
                               calendars: protocol.calendars)
          end
        end
        new(calendar: calendar, kind: kind, rules: rules)
      end

      def initialize(calendar:, kind:, rules:)
        self.calendar = calendar
        self.kind = kind
        self.rules = rules
      end

      # Runs `check` on each rule for the given event and returns any error info.
      def errors(event)
        rules.map { |r| r.check(event) }.reject { |v| v == true }
      end

      # Returns one of [ok, read_only, sponsor, forbidden] to describe the access level of
      # the given creator vis a vis the rule set's calendar. This is for displaying the calendar
      # or the event page. It doesn't check whether an event is valid. See the .check method for that.
      def access_level(creator_community)
        return "ok" if calendar_community == creator_community

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

      def timed_events_only?
        !calendar.all_day_allowed? || fixed_start_time.present? || fixed_end_time.present?
      end

      def to_s
        rules.map(&:to_s).join("\n")
      end

      private

      attr_accessor :calendar, :kind, :rules

      delegate :community, to: :calendar, prefix: true

      def values_for(rule_name)
        rules_by_name[rule_name]&.map(&:value) || []
      end

      def rules_by_name
        @rules_by_name ||= rules.group_by(&:name)
      end
    end
  end
end
