# frozen_string_literal: true

module Reservations
  class Reservation < ApplicationRecord
    NAME_MAX_LENGTH = 24

    acts_as_tenant :cluster

    self.table_name = "reservations"

    attr_accessor :guidelines_ok, :privileged_changer
    alias privileged_changer? privileged_changer

    belongs_to :reserver, class_name: "User"
    belongs_to :sponsor, class_name: "User"
    belongs_to :resource, inverse_of: :reservations
    belongs_to :meal, class_name: "Meals::Meal", inverse_of: :reservations

    scope :with_max_age, ->(age) { where("starts_at >= ?", Time.current - age) }
    scope :oldest_first, -> { order(:starts_at, :ends_at) }
    scope :related_to, ->(user) { where(reserver: user).or(where(sponsor: user)) }

    # Satisfies ducktype expected by policies. Prefer more explicit variants reserver_community
    # and sponsor_community for other uses.
    delegate :community, to: :resource, allow_nil: true

    delegate :household, to: :reserver
    delegate :users, to: :household, prefix: true
    delegate :name, :community, to: :reserver, prefix: true
    delegate :name, to: :reserver_community, prefix: true
    delegate :community, to: :sponsor, prefix: true, allow_nil: true
    delegate :community_id, to: :resource
    delegate :name, to: :resource, prefix: true
    delegate :access_level, :fixed_start_time?, :fixed_end_time?, :requires_kind?, to: :rule_set

    validates :name, presence: true, length: {maximum: NAME_MAX_LENGTH}
    validates :resource_id, :reserver_id, :starts_at, :ends_at, presence: true
    validate :guidelines_accepted
    validate :start_before_end
    validate :restrict_changes_in_past
    validate :no_overlap
    validate :apply_rules
    validate lambda { |r| # Satisfies ducktype expected by policies. Prefer more explicit variants reserver_community
               # and sponsor_community for other uses.
               # Set fixed start/end time
               # We add an underscore to differentiate from user-specified kinds
               meal&.reservation_handler&.validate_reservation(r)
             }

    before_save lambda { |r| # Satisfies ducktype expected by policies. Prefer more explicit variants reserver_community
                  # and sponsor_community for other uses.
                  # Set fixed start/end time
                  # We add an underscore to differentiate from user-specified kinds
                  # rubocop:disable Style/GuardClause # || structure
                  meal&.reservation_handler&.sync_resourcings(r)
                }

    normalize_attributes :kind, :note

    def self.new_with_defaults(attribs)
      reservation = new(attribs)

      reservation.starts_at ||= Time.current.midnight + 1.week + 17.hours
      reservation.ends_at ||= Time.current.midnight + 1.week + 18.hours

      # Set fixed start/end time
      rule_set = reservation.rule_set
      if fst = rule_set.fixed_start_time
        reservation.starts_at = reservation.starts_at.change(hour: fst.hour, min: fst.min)
      end
      if fet = rule_set.fixed_end_time
        reservation.ends_at = reservation.ends_at.change(hour: fet.hour, min: fet.min)
      end
      reservation.ends_at += 1.day if reservation.starts_at >= reservation.ends_at

      reservation
    end

    def displayable_kind?
      kind.present? && !meal?
    end

    def seconds
      ends_at - starts_at
    end

    def minutes
      (seconds.to_f / 1.minute).ceil
    end

    def days
      (seconds.to_f / 1.day).ceil
    end

    def rule_set
      @rule_set ||= Rules::RuleSet.build_for(resource: resource, kind: kind)
    end

    def future?
      starts_at.try(:future?)
    end

    def recently_created?
      Time.current - created_at < 1.hour
    end

    def guidelines_ok?
      guidelines_ok == "1"
    end

    def timespan
      I18n.l(starts_at) << " - " << I18n.l(ends_at, format: single_day? ? :time_only : :default)
    end

    def single_day?
      ends_at.to_date == starts_at.to_date
    end

    def meal?
      # We add an underscore to differentiate from user-specified kinds
      kind == "_meal"
    end

    private

    def guidelines_accepted
      return unless new_record? && resource.guidelines? && !guidelines_ok?
      errors.add(:guidelines, "You must agree to the guidelines")
    end

    def start_before_end
      return unless starts_at.present? && ends_at.present? && starts_at >= ends_at
      errors.add(:ends_at, "must be after start time")
    end

    def no_overlap
      query = self.class.where("ends_at > ? AND starts_at < ?", starts_at, ends_at)
      query = query.where(resource_id: resource_id)
      query = query.where("id != #{id}") if persisted?
      errors.add(:base, "This reservation overlaps an existing one") if query.any?
    end

    def apply_rules
      return if errors.any?
      rule_set.errors(self).each { |e| errors.add(*e) }
    end

    def restrict_changes_in_past
      return unless persisted? && !recently_created? && !privileged_changer?
      if will_save_change_to_starts_at? && starts_at_was&.past?
        errors.add(:starts_at, "can't be changed after reservation begins")
      end
      if will_save_change_to_ends_at? && ends_at&.past? # rubocop:disable Style/GuardClause # || structure
        errors.add(:ends_at, "can't be changed to a time in the past")
      end
    end
  end
end
