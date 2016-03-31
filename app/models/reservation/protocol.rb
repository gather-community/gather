# Models a protocol for a set of resources and an optional reservation kind.
# Multiple protocols can exist for a single resource.
#
# Typical use cases:
# One protocol sets max_lead_days for a given kind for all resources.
# Another sets max_minutes_per_year for a subset of resources.
# etc.
#
# Rule attributes:
#   fixed_start_time
#   fixed_end_time
#   max_lead_days
#   max_length_minutes
#   max_minutes_per_year
#   requires_sponsor
module Reservation
  class Protocol < ActiveRecord::Base
    has_many :protocolings, class_name: "Reservation::Protocoling", foreign_key: "protocol_id"
    has_many :resources, through: :protocolings

    serialize :kinds

    RULE_ATTRIBS = %i(fixed_start_time fixed_end_time max_lead_days
      max_length_minutes max_minutes_per_year requires_sponsor)

    # Finds all matching protocols and unions them into one.
    # Returns a hash of Reservation::Rules that represent the unified protocols.
    # Raises an error if any two protocols have non-nil values for the same attrib.
    def self.rules_for(resource, kind = nil)
      protocols = matching(resource, kind)
      {}.tap do |result|
        RULE_ATTRIBS.each do |a|
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
    end

    # Finds all matching protocols for the given resource and kind.
    # If kind is given, matches protocols with given kind or with nil kind.
    # If kind is nil, matches protocols with nil kind only.
    def self.matching(resource, kind = nil)
      includes(:protocolings).where("reservation_protocolings.resource_id": resource.id).
        select { |p| p.has_kind?(kind) || p.kinds.nil? }
    end

    def has_kind?(k)
      kinds.present? && kinds.include?(k)
    end
  end

  class ProtocolDuplicateDefinitionError < StandardError
    attr_accessor :attrib, :protocols

    def initialize(attrib: nil, protocols: nil)
      self.attrib = attrib
      self.protocols = protocols
      super("Multiple protocols define #{attrib}")
    end
  end
end
