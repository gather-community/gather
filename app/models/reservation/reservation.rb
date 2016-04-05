module Reservation
  class Reservation < ActiveRecord::Base
    self.table_name = "reservations"

    belongs_to :user, foreign_key: "reserver_id"
    belongs_to :sponsor, class_name: "User"
    belongs_to :resource

    delegate :household, to: :user
    delegate :community, to: :user, prefix: true
    delegate :community, to: :sponsor, prefix: true, allow_nil: true

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
  end
end