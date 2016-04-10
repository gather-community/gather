module Reservation
  class Reservation < ActiveRecord::Base
    self.table_name = "reservations"

    belongs_to :user, foreign_key: "reserver_id"
    belongs_to :sponsor, class_name: "User"
    belongs_to :resource

    delegate :household, to: :user
    delegate :community, to: :user, prefix: true
    delegate :community, to: :sponsor, prefix: true, allow_nil: true

    validates :name, presence: true, length: { maximum: 24 }
    validates :resource_id, :reserver_id, :starts_at, :ends_at, presence: true
    validate :start_before_end
    validate :no_overlap
    validate :apply_rules

    # Counts the number of seconds or days booked for the given resources by the given
    # household over the given period.
    # The number of days is rounded up for each event.
    # i.e., a 1-hour event and a 10-hour event both counts as 1 day, while a 36-hour event
    # counts as 2 days.
    def self.booked_time_for(resources:, household:, period:, unit:)
      where(resource: resources, user: household.users, starts_at: period).to_a.sum(&unit)
    end

    def seconds
      ends_at - starts_at
    end

    def days
      (seconds.to_f / 1.day).ceil
    end

    def rules
      RuleSet.build_for(self).rules
    end

    def future?
      starts_at.future?
    end

    def recently_created?
      Time.now - created_at < 1.hour
    end

    private

    def start_before_end
      if starts_at.present? && ends_at.present? && starts_at >= ends_at
        errors.add(:ends_at, "must be after start time")
      end
    end

    def no_overlap
      query = self.class.where("ends_at > ? AND starts_at < ?", starts_at, ends_at)
      query = query.where("id != #{id}") if persisted?
      errors.add(:base, "This reservation overlaps an existing one") if query.any?
    end

    def apply_rules
      rules.each do |_, rule|
        # Check returns 2 element array on failure
        unless (result = rule.check(self)) == true
          errors.add(*result)
        end
      end
    end
  end
end