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
    has_many :resources, -> { by_name }, through: :protocolings
    belongs_to :community

    delegate :name, to: :community, prefix: true

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :by_name, -> { alpha_order(:name) }

    normalize_attributes :name, :pre_notice, :other_communities

    before_validation :normalize

    validates :name, presence: true, length: {maximum: 64}
    validates :max_lead_days, :max_length_minutes, :max_days_per_year, :max_minutes_per_year,
      numericality: {greater_than: 0}, allow_nil: true

    # Finds all matching protocols for the given resource and kind.
    # If kind is given, matches protocols with given kind or with nil kind.
    # If kind is nil, matches protocols with nil kind only.
    def self.matching(resource, kind = nil)
      resource_id_expr = "(SELECT resource_id FROM reservation_protocolings "\
        "WHERE protocol_id = reservation_protocols.id)"
      result = where(community_id: resource.community_id)
        .where(":id IN #{resource_id_expr} OR NOT EXISTS #{resource_id_expr}", id: resource.id)
        .order(:created_at) # Need a definite ordering for specs
      result = result.where("kinds IS NULL OR kinds ? :kind", kind: kind) unless kind == :any
      result
    end

    # A protocol is general if it is not applied to any specific resources.
    def general?
      resources.none?
    end

    private

    def normalize
      # Can only be true if set to true and no kinds. nil otherwise. Should never be false.
      self.kinds = kinds.reject(&:blank?).presence unless kinds.nil?
      self.requires_kind = !kinds&.any? && requires_kind? || nil
    end
  end
end
