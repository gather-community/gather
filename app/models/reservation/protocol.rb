module Reservation
  class Protocol < ActiveRecord::Base
    has_many :protocolings, class_name: "Reservation::Protocoling", foreign_key: "protocol_id"
    has_many :resources, through: :protocolings

    serialize :kinds

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
end
