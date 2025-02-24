# frozen_string_literal: true

module Calendars
  # Models a protocol for a set of calendars and an optional event kind.
  # Multiple protocols can exist for a single calendar.
  #
  # Typical use cases:
  # One protocol sets max_lead_days for a given kind for all calendars.
  # Another sets max_minutes_per_year for a subset of calendars.
  # etc.
  #
# == Schema Information
#
# Table name: calendar_protocols
#
#  id                   :integer          not null, primary key
#  fixed_end_time       :time
#  fixed_start_time     :time
#  kinds                :jsonb
#  max_days_per_year    :integer
#  max_lead_days        :integer
#  max_length_minutes   :integer
#  max_minutes_per_year :integer
#  name                 :string           not null
#  other_communities    :string
#  pre_notice           :text
#  requires_kind        :boolean
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  cluster_id           :integer          not null
#  community_id         :integer          not null
#
# Indexes
#
#  index_calendar_protocols_on_cluster_id    (cluster_id)
#  index_calendar_protocols_on_community_id  (community_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#
  # See Calendars::Rule::NAMES for list of rule attributes
  class Protocol < ApplicationRecord
    acts_as_tenant :cluster

    has_many :protocolings, class_name: "Calendars::Protocoling", inverse_of: :protocol,
                            foreign_key: "protocol_id", dependent: :destroy
    has_many :calendars, -> { by_name }, class_name: "Calendars::Calendar", through: :protocolings
    belongs_to :community

    delegate :name, to: :community, prefix: true

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :by_name, -> { alpha_order(:name) }

    normalize_attributes :name, :pre_notice, :other_communities

    before_validation :normalize

    validates :name, presence: true, length: {maximum: 64}
    validates :max_lead_days, :max_length_minutes, :max_days_per_year, :max_minutes_per_year,
              numericality: {greater_than: 0}, allow_nil: true

    # Finds all matching protocols for the given calendar and kind.
    # If kind is given, matches protocols with given kind or with nil kind.
    # If kind is nil, matches protocols with nil kind only.
    def self.matching(calendar, kind = nil)
      calendar_id_expr = "(SELECT calendar_id FROM calendar_protocolings "\
        "WHERE protocol_id = calendar_protocols.id)"
      result = where(community_id: calendar.community_id)
        .where(":id IN #{calendar_id_expr} OR NOT EXISTS #{calendar_id_expr}", id: calendar.id)
        .order(:created_at) # Need a definite ordering for specs
      result = result.where("kinds IS NULL OR kinds ? :kind", kind: kind) unless kind == :any
      result
    end

    # A protocol is general if it is not applied to any specific calendars.
    def general?
      calendars.none?
    end

    private

    def normalize
      # Can only be true if set to true and no kinds. nil otherwise. Should never be false.
      self.kinds = kinds.reject(&:blank?).presence unless kinds.nil?
      self.requires_kind = !kinds&.any? && requires_kind? || nil
    end
  end
end
