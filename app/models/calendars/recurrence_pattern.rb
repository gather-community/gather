# frozen_string_literal: true

module Calendars
  # The repeat settings the event form offers, and the IceCube rule they stand for.
  #
  # The start is always the series' first occurrence, which the drag, split and re-keying code relies
  # on (Event#assert_starts_on_schedule). So the days a series repeats on always include its start's:
  # a weekly series is on the start's weekday plus any others chosen, a monthly one on the start's date
  # or its weekday in the month, and a yearly one on its date. Weekly and monthly rules name the days
  # explicitly, which also stops a drag from moving the series to a day the pattern excludes
  # (EventletForm#series_pattern_allows_move).
  class RecurrencePattern
    include ActiveModel::Model

    FREQUENCIES = %w[daily weekly monthly yearly].freeze
    # "Day 31" or "the last day of the month"; "the 4th Tuesday" or "the last Tuesday". A date in the
    # last week of its month can be both of the latter, but a fifth Tuesday is only ever the last, as
    # most months don't have one. See .monthly_by_options.
    MONTHLY_BY = %w[day_of_month last_day_of_month day_of_week last_day_of_week].freeze
    ENDS = %w[never on_date after_count].freeze
    MAX_INTERVAL = 99
    MAX_COUNT = 999

    # Keyed by rule class name, as a rule's hash gives it.
    RULE_TYPES = {IceCube::DailyRule => "daily", IceCube::WeeklyRule => "weekly",
                  IceCube::MonthlyRule => "monthly", IceCube::YearlyRule => "yearly"}
      .transform_keys(&:name).freeze

    # The shortest gap between two occurrences for each frequency, per unit of interval, so an event
    # can be checked against it: a longer event would overlap its own next occurrence.
    MIN_GAPS = {"daily" => 1.day, "weekly" => 7.days, "monthly" => 28.days, "yearly" => 365.days}.freeze

    attr_accessor :monthly_by, :ends
    attr_writer :interval, :ends_on, :count
    attr_reader :frequency

    # The form's "Never" option is sent as "none".
    def frequency=(value)
      @frequency = (value.to_s == "none") ? nil : value.presence
    end

    # Weekdays as numbers, Sunday being 0, from the form's checkboxes (which send a blank alongside).
    def weekdays=(value)
      @weekdays = Array(value).reject(&:blank?).map(&:to_i).uniq.sort
    end

    validates :frequency, inclusion: {in: FREQUENCIES}, allow_blank: true
    validates :interval, if: :recurring?,
      numericality: {only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_INTERVAL}
    validates :monthly_by, inclusion: {in: MONTHLY_BY}, if: -> { frequency == "monthly" }
    validate :weekdays_in_range
    validates :ends, inclusion: {in: ENDS}, if: :recurring?
    validates :ends_on, presence: true, if: -> { recurring? && ends == "on_date" }
    validates :count, numericality: {only_integer: true, greater_than: 1, less_than_or_equal_to: MAX_COUNT},
      if: -> { recurring? && ends == "after_count" }

    # The pattern an existing rule stands for, or nil if it's one the form can't show, such as a monthly
    # rule on two dates. Callers keep such a rule as it is.
    def self.from_rule(rule_hash)
      return new(ends: "never", interval: 1, monthly_by: "day_of_month", weekdays: []) if rule_hash.blank?
      rule = IceCube::Rule.from_hash(rule_hash)
      hash = rule.to_hash
      frequency = RULE_TYPES[hash[:rule_type]]
      validations = hash[:validations] || {}
      return nil if frequency.nil? || !representable?(frequency, validations)

      new(frequency: frequency, interval: hash[:interval] || 1, ends: ends_for(rule),
        monthly_by: monthly_by_for(validations), weekdays: validations[:day] || [],
        ends_on: rule.until_time&.to_date, count: hash[:count])
    end

    # The ways a monthly series starting on this date can repeat: always on its date (which skips
    # months too short to have it, e.g. the 31st); on the last day of the month if it's that; on its
    # weekday in the month (e.g. the 4th Tuesday) unless it's the fifth, which most months lack; and on
    # the last such weekday if it's in the last week of the month. The last day is only offered on the
    # last day, as the start has to be one of the series' occurrences.
    def self.monthly_by_options(date)
      MONTHLY_BY.select do |by|
        case by
        when "day_of_month" then true
        when "last_day_of_month" then date.to_date == date.to_date.end_of_month
        when "day_of_week" then nth_weekday(date) <= 4
        when "last_day_of_week" then date.day + 7 > date.end_of_month.day
        end
      end
    end

    # Which week of the month the date's weekday falls in, from 1 to 5.
    def self.nth_weekday(date)
      ((date.day - 1) / 7) + 1
    end

    # The choice that stays closest to the given one for a start date that doesn't offer it, e.g. after
    # the start moves from the 4th Tuesday to the 5th: "the 4th" becomes "the last" and vice versa.
    def self.closest_monthly_by(monthly_by, date)
      options = monthly_by_options(date)
      return monthly_by if options.include?(monthly_by)
      fallback = {"day_of_week" => "last_day_of_week", "last_day_of_week" => "day_of_week"}[monthly_by]
      options.include?(fallback) ? fallback : "day_of_month"
    end

    def self.monthly_by_for(validations)
      return "last_day_of_month" if validations[:day_of_month] == [-1]
      nths = validations[:day_of_week]&.values&.first
      return "day_of_month" if nths.nil?
      (nths == [-1]) ? "last_day_of_week" : "day_of_week"
    end
    private_class_method :monthly_by_for

    def self.ends_for(rule)
      if rule.until_time
        "on_date"
      elsif rule.to_hash[:count]
        "after_count"
      else
        "never"
      end
    end
    private_class_method :ends_for

    # Only the validations to_rule_hash itself adds, or none (a bare rule takes its day from the start).
    # A weekly rule may name several days; a monthly one names a single date or weekday.
    def self.representable?(frequency, validations)
      allowed = {"daily" => [], "weekly" => %i[day], "monthly" => %i[day_of_month day_of_week],
                 "yearly" => []}
      return false unless validations.keys.map(&:to_sym).all? { |key| allowed[frequency].include?(key) }
      return true if frequency == "weekly"
      validations.values.all? do |value|
        value.is_a?(Hash) ? (value.size == 1 && value.values.first.size == 1) : Array(value).size <= 1
      end
    end
    private_class_method :representable?

    def recurring?
      frequency.present?
    end

    def interval
      @interval.presence&.to_i || 1
    end

    def count
      @count.presence&.to_i
    end

    # The numericality validations check the values as submitted, so "1.5" is refused rather than read
    # as 1. Rails looks for these methods to find the submitted value.
    %i[interval count].each do |attr|
      define_method(:"#{attr}_came_from_user?") { instance_variable_get(:"@#{attr}").present? }
      define_method(:"#{attr}_before_type_cast") { instance_variable_get(:"@#{attr}") }
    end

    def weekdays
      @weekdays || []
    end

    # The days a weekly series starting at the given time falls on: those chosen, and always the start's.
    def weekdays_for(starts_at)
      (weekdays | [starts_at.wday]).sort
    end

    def ends_on
      return @ends_on if @ends_on.nil? || @ends_on.is_a?(Date)
      Date.parse(@ends_on.to_s)
    rescue Date::Error
      nil
    end

    # The IceCube rule hash for a series starting at the given time, or nil if it doesn't repeat.
    def to_rule_hash(starts_at, all_day:)
      return nil unless recurring?
      rule = base_rule(starts_at)
      case ends
      when "on_date" then rule.until(until_time(starts_at, all_day))
      when "after_count" then rule.count(count)
      end
      rule.to_hash
    end

    # Identifies which days the series falls on, leaving out the time of day and the end, so a change
    # to it can be told apart from a change to the time or the end.
    def days_key(starts_at)
      return nil unless recurring?
      day =
        case frequency
        when "weekly" then weekdays_for(starts_at)
        when "monthly" then monthly_day(starts_at)
        when "yearly" then [starts_at.month, starts_at.day]
        end
      [frequency, interval, (monthly_by if frequency == "monthly"), day]
    end

    def ends_key
      [ends, (ends_on if ends == "on_date"), (count if ends == "after_count")]
    end

    # The shortest time between the starts of two occurrences. Weekly on several days, it's the
    # closest two days, counting the wrap from the last day of one week to the first of the next.
    def min_gap(starts_at)
      return MIN_GAPS[frequency] * interval unless frequency == "weekly"
      days = weekdays_for(starts_at)
      gaps = days.each_cons(2).map { |a, b| b - a }
      gaps << (days.first + 7 - days.last) + (7 * (interval - 1))
      gaps.min.days
    end

    private

    def base_rule(starts_at)
      case frequency
      when "daily" then IceCube::Rule.daily(interval)
      when "weekly" then IceCube::Rule.weekly(interval).day(*weekdays_for(starts_at))
      when "monthly"
        rule = IceCube::Rule.monthly(interval)
        day = monthly_day(starts_at)
        day.is_a?(Array) ? rule.day_of_week(day.first => [day.last]) : rule.day_of_month(day)
      when "yearly" then IceCube::Rule.yearly(interval)
      end
    end

    # The start's date, or its weekday and which one in the month (-1 for the last).
    def monthly_day(starts_at)
      case monthly_by
      when "day_of_week" then [starts_at.wday, self.class.nth_weekday(starts_at)]
      when "last_day_of_week" then [starts_at.wday, -1]
      when "last_day_of_month" then -1
      else starts_at.day
      end
    end

    def weekdays_in_range
      errors.add(:weekdays, :inclusion) unless weekdays.all? { |d| (0..6).cover?(d) }
    end

    # UNTIL is inclusive. Placing it at the series' time of day on the end date means an occurrence
    # that day is kept. An all-day series starts at midnight, so midnight on the end date.
    def until_time(starts_at, all_day)
      day = ends_on
      return day.in_time_zone if all_day
      Time.zone.local(day.year, day.month, day.day, starts_at.hour, starts_at.min, starts_at.sec)
    end
  end
end
