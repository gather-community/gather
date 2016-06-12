module Reservation
  class Reservation < ActiveRecord::Base
    NAME_MAX_LENGTH = 24
    self.table_name = "reservations"

    attr_accessor :guidelines_ok

    belongs_to :reserver, class_name: "User"
    belongs_to :sponsor, class_name: "User"
    belongs_to :resource
    belongs_to :meal

    delegate :household, to: :reserver
    delegate :name, :community, to: :reserver, prefix: true
    delegate :name, to: :reserver_community, prefix: true
    delegate :community, to: :sponsor, prefix: true, allow_nil: true
    delegate :community_id, to: :resource
    delegate :name, :full_name, to: :resource, prefix: true
    delegate :title, to: :meal, prefix: true
    delegate :access_level, :fixed_start_time?, :fixed_end_time?, :requires_kind?, to: :rule_set

    validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
    validates :resource_id, :reserver_id, :starts_at, :ends_at, presence: true
    validate :guidelines_accepted
    validate :start_before_end
    validate :no_overlap
    validate :apply_rules

    normalize_attributes :kind, :note

    # Counts the number of seconds or days booked for the given resources by the given
    # household over the given period.
    # The number of days is rounded up for each event.
    # i.e., a 1-hour event and a 10-hour event both counts as 1 day, while a 36-hour event
    # counts as 2 days.
    def self.booked_time_for(resources:, household:, period:, unit:)
      where(resource: resources, reserver: household.users, starts_at: period).to_a.sum(&unit)
    end

    def self.new_with_defaults(attribs)
      reservation = new(attribs)

      reservation.starts_at ||= Time.zone.now.midnight + 1.week + 17.hours
      reservation.ends_at ||= Time.zone.now.midnight + 1.week + 18.hours

      # Set fixed start/end time
      rule_set = reservation.rule_set
      if fst = rule_set[:fixed_start_time].try(:value)
        reservation.starts_at = reservation.starts_at.change(hour: fst.hour, min: fst.min)
      end
      if fet = rule_set[:fixed_end_time].try(:value)
        reservation.ends_at = reservation.ends_at.change(hour: fet.hour, min: fet.min)
      end
      if reservation.starts_at >= reservation.ends_at
        reservation.ends_at = reservation.ends_at.change(day: reservation.ends_at.day + 1)
      end

      reservation
    end

    def seconds
      ends_at - starts_at
    end

    def days
      (seconds.to_f / 1.day).ceil
    end

    def rule_set
      @rule_set ||= RuleSet.build_for(self)
    end

    def future?
      starts_at.future?
    end

    def recently_created?
      Time.now - created_at < 1.hour
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
      if new_record? && resource.has_guidelines? && !guidelines_ok?
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
      rule_set.rules.each do |_, rule|
        # Check returns 2 element array on failure
        unless (result = rule.check(self)) == true
          errors.add(*result)
        end
      end
    end
  end
end