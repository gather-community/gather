# Models a protocol for a set of resources and an optional reservation kind.
# Multiple protocols can exist for a single resource.
#
# Typical use cases:
# One protocol sets max_lead_days for a given kind for all resources.
# Another sets max_minutes_per_year for a subset of resources.
# etc.
#
# See Reservation::Rule::NAMES for list of rule attributes
module Reservation
  class Protocol < ActiveRecord::Base
    has_many :protocolings, class_name: "Reservation::Protocoling", foreign_key: "protocol_id"
    has_many :resources, through: :protocolings

    serialize :kinds, JSON

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

    def community
      resources.first.try(:community)
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
