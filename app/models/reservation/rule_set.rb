# Models a set of Rules governing a single reservation.
# Represents the unification of one or more protocols.
module Reservation
  class RuleSet
    attr_accessor :reservation, :rules

    # Finds all matching protocols and unions them into one.
    # Raises an error if any two protocols have non-nil values for the same attrib.
    def self.build_for(reservation)
      protocols = Protocol.matching(reservation.resource, reservation.kind)

      rules = {}.tap do |result|
        Rule::NAMES.each do |a|
          protocols_with_attr = protocols.select{ |p| p[a].present? }

          if protocols_with_attr.size > 1
            raise ProtocolDuplicateDefinitionError.new(attrib: a, protocols: protocols_with_attr)
          elsif protocols_with_attr.size == 0
            next
          end

          protocol = protocols_with_attr.first
          result[a] = Rule.new(name: a, value: protocol[a], protocol: protocol)
        end
      end

      new(reservation: reservation, rules: rules)
    end

    def initialize(reservation:, rules:)
      self.reservation = reservation
      self.rules = rules
    end
  end
end
