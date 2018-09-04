# frozen_string_literal: true

module Reservations
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
        filtered = protocols.select { |p| p[rule_name].present? }
        next if filtered.empty?
        rules[rule_name] = Rule.new(
          name: rule_name,
          value: aggregate(filtered, rule_name),
          community: reservation.community,
          resources: filtered.flat_map(&:resources).uniq
        )
      end
      new(reservation: reservation, rules: rules)
    end

    def initialize(reservation:, rules:)
      self.reservation = reservation
      self.rules = rules
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

    def self.aggregate(protocols, rule_name)
      values = protocols.map(&rule_name)
      case rule_name
      when :fixed_start_time, :max_lead_days, :max_length_minutes, :max_minutes_per_year, :max_days_per_year
        values.min
      when :fixed_end_time
        values.max
      when :other_communities
        values.max_by { |v| Rule::OTHER_COMMUNITIES_VALUES.index(v.to_sym) }
      when :requires_kind
        values.any?
      when :pre_notice
        values.join("\n")
      end
    end
  end
end
