# frozen_string_literal: true

module Reservations
  # Models a protocol for a set of resources and an optional reservation kind.
  # Multiple protocols can exist for a single resource.
  #
  # Typical use cases:
  # One protocol sets max_lead_days for a given kind for all resources.
  # Another sets max_minutes_per_year for a subset of resources.
  # etc.
  #
  # See Reservations::Rule::NAMES for list of rule attributes
  class Protocol < ApplicationRecord
    acts_as_tenant :cluster

    has_many :protocolings, class_name: "Reservations::Protocoling", inverse_of: :protocol,
                            foreign_key: "protocol_id", dependent: :destroy
    has_many :resources, through: :protocolings
    belongs_to :community

    delegate :name, to: :community, prefix: true

    scope :in_community, ->(c) { where(community_id: c.id) }

    # Finds all matching protocols for the given resource and kind.
    # If kind is given, matches protocols with given kind or with nil kind.
    # If kind is nil, matches protocols with nil kind only.
    def self.matching(resource, kind = nil)
      joins("LEFT JOIN reservation_protocolings
          ON reservation_protocolings.protocol_id = reservation_protocols.id")
        .where(community_id: resource.community_id)
        .where("reservation_protocolings.resource_id = ? OR general = 't'", resource.id)
        .select { |p| p.applies_to_kind?(kind) || p.kinds.nil? }
    end

    private

    def applies_to_kind?(kind)
      kinds.present? && kinds.include?(kind)
    end
  end
end
