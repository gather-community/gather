# frozen_string_literal: true

module Calendars
  # The move between two times, expressed the way a person reads a clock: a number of calendar days
  # plus a change in local time of day. Applying it to another time keeps that time's local clock
  # reading consistent across DST changes, the same way IceCube lays out a series' occurrences.
  #
  # Adding a fixed duration instead (`time + (new - old)`) drifts an hour whenever the shift crosses a
  # DST change, which would move a 7pm series to 6pm or 8pm on the far side of it.
  #
  # Works to the second; sub-second parts are dropped.
  class WallClockShift
    SECONDS_PER_DAY = 86_400

    attr_reader :days, :seconds

    def initialize(old_time, new_time)
      old_time = old_time.in_time_zone
      new_time = new_time.in_time_zone
      @days = (new_time.to_date - old_time.to_date).to_i
      @seconds = clock_seconds(new_time) - clock_seconds(old_time)
    end

    # The time of day can leave 0–24h when the given time's clock reading differs from the one the
    # shift was measured on (e.g. 10:30pm shifted by "next day, 23 hours earlier"), so any whole days
    # it overflows by are carried into the date.
    def apply(time)
      time = time.in_time_zone
      total = clock_seconds(time) + seconds
      date = time.to_date + days + total.div(SECONDS_PER_DAY)
      total %= SECONDS_PER_DAY
      Time.zone.local(date.year, date.month, date.day, total / 3600, (total % 3600) / 60, total % 60)
    end

    def zero?
      days.zero? && seconds.zero?
    end

    private

    # Seconds since local midnight as read off the clock, so 7pm is 19 hours even on a DST day.
    def clock_seconds(time)
      (time.hour * 3600) + (time.min * 60) + time.sec
    end
  end
end
