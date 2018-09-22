module Reservations
  class Reservation < ApplicationRecord
    NAME_MAX_LENGTH = 24

    acts_as_tenant :cluster

    self.table_name = "reservations"

    attr_accessor :guidelines_ok

    belongs_to :reserver, class_name: "User"
    belongs_to :sponsor, class_name: "User"
    belongs_to :resource
    belongs_to :meal

    scope :with_max_age, ->(age) { where("starts_at >= ?", Time.current - age) }
    scope :oldest_first, -> { order(:starts_at, :ends_at) }

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
    delegate :title_or_no_title, to: :meal, prefix: true
    delegate :access_level, :fixed_start_time?, :fixed_end_time?, :requires_kind?, to: :rule_set

    validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
    validates :resource_id, :reserver_id, :starts_at, :ends_at, presence: true
    validate :guidelines_accepted
    validate :start_before_end
    validate :no_overlap
    validate :apply_rules
    validate ->(r) { meal.reservation_handler.validate_reservation(r) if meal }

    before_save ->(r) { meal.reservation_handler.sync_resourcings(r) if meal }

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
      if reservation.starts_at >= reservation.ends_at
        reservation.ends_at += 1.day
      end

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
      starts_at.to_s(:full_datetime) << " - " <<
        ends_at.to_s(single_day? ? :regular_time : :full_datetime)
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
      if new_record? && resource.guidelines? && !guidelines_ok?
        errors.add(:guidelines, "You must agree to the guidelines")
      end
    end

    def start_before_end
      if starts_at.present? && ends_at.present? && starts_at >= ends_at
        errors.add(:ends_at, "must be after start time")
      end
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
  end
end
