# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_protocols
#
#  id                   :integer          not null, primary key
#  cluster_id           :integer          not null
#  community_id         :integer          not null
#  created_at           :datetime         not null
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
#  updated_at           :datetime         not null
#
module Calendars
  # Models a protocol for a set of calendars and an optional event kind.
  # Multiple protocols can exist for a single calendar.
  #
  # Typical use cases:
  # One protocol sets max_lead_days for a given kind for all calendars.
  # Another sets max_minutes_per_year for a subset of calendars.
  # etc.
  #
  # See Calendars::Rule::NAMES for list of rule attributes
  class Protocol < ApplicationRecord
    acts_as_tenant :cluster

    # Rules a repeating event can't keep to, so a calendar with any of them can't have one (see
    # Calendar#allows_recurring_events?). These block recurrence whatever kinds the protocol covers.
    # - Fixed start/end times: a series can't follow a snap to a fixed time.
    # - Max lead days: a series that never ends always reaches past it.
    # - Yearly quotas: MaxTimePerYearRule counts one row per event, so a whole series would count as a
    #   single event, and only in the year it starts.
    RECURRENCE_BLOCKING_RULES = %i[fixed_start_time fixed_end_time max_lead_days max_days_per_year
      max_minutes_per_year].freeze

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
    validate :no_repeating_events_on_blocked_calendars

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

    # The calendars this protocol applies to: its own, or every calendar in its community if it has
    # none (see .matching).
    def applicable_calendars
      general? ? Calendar.non_system.in_community(community) : calendars
    end

    def blocks_recurrence?
      RECURRENCE_BLOCKING_RULES.any? { |rule| self[rule].present? }
    end

    private

    # A rule that blocks recurrence can't apply to a calendar that has a repeating event still to come.
    # Covers each way a protocol can newly reach such a calendar: gaining the rule, gaining the
    # calendar, or losing its last calendar, which makes it apply to every calendar in the community.
    def no_repeating_events_on_blocked_calendars
      return unless blocks_recurrence? && community
      names = applicable_calendars.select(&:upcoming_recurring_events?).map(&:name)
      return if names.empty?
      errors.add(:base, :repeating_events, calendars: names.sort.to_sentence)
    end

    def normalize
      # Can only be true if set to true and no kinds. nil otherwise. Should never be false.
      self.kinds = kinds.reject(&:blank?).presence unless kinds.nil?
      self.requires_kind = !kinds&.any? && requires_kind? || nil
    end
  end
end
