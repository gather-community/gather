# Models a protocol for a set of resources and an optional reservation kind.
# Multiple protocols can exist for a single resource.
#
# Typical use cases:
# One protocol sets max_lead_days for a given kind for all resources.
# Another sets max_minutes_per_year for a subset of resources.
# etc.
#
# See Reservations::Rule::NAMES for list of rule attributes
module Reservations
  class Protocol < ApplicationRecord
    acts_as_tenant :cluster

    has_many :protocolings, class_name: "Reservations::Protocoling",
      foreign_key: "protocol_id", dependent: :destroy
    has_many :resources, through: :protocolings
    belongs_to :community

    delegate :name, to: :community, prefix: true

    serialize :kinds, JSON

    # Finds all matching protocols for the given resource and kind.
    # If kind is given, matches protocols with given kind or with nil kind.
    # If kind is nil, matches protocols with nil kind only.
    def self.matching(resource, kind = nil)
      joins("LEFT JOIN reservation_protocolings
          ON reservation_protocolings.protocol_id = reservation_protocols.id").
        where(community_id: resource.community_id).
        where("reservation_protocolings.resource_id = ? OR general = 't'", resource.id).
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
