# frozen_string_literal: true

module Calendars
  # The repeat settings the event form offers, and the IceCube rule they stand for.
  #
  # The day a series repeats on always comes from its start: weekly on the start's weekday, monthly on
  # its date or its nth weekday, yearly on its date. So the start is always the series' first
  # occurrence, which the drag, split and re-keying code relies on, and there's no separate day picker
  # to disagree with it. Weekly and monthly rules name the day explicitly, which also stops a drag from
  # moving the series to a day the pattern excludes (EventletForm#series_pattern_allows_move).
  class RecurrencePattern
    include ActiveModel::Model

    FREQUENCIES = %w[daily weekly monthly yearly].freeze
    MONTHLY_BY = %w[day_of_month day_of_week].freeze
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

    validates :frequency, inclusion: {in: FREQUENCIES}, allow_blank: true
    validates :interval, if: :recurring?,
      numericality: {only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_INTERVAL}
    validates :monthly_by, inclusion: {in: MONTHLY_BY}, if: -> { frequency == "monthly" }
    validates :ends, inclusion: {in: ENDS}, if: :recurring?
    validates :ends_on, presence: true, if: -> { recurring? && ends == "on_date" }
    validates :count, numericality: {only_integer: true, greater_than: 1, less_than_or_equal_to: MAX_COUNT},
      if: -> { recurring? && ends == "after_count" }

    # The pattern an existing rule stands for, or nil if it's one the form can't show, such as a weekly
    # rule on several days. Callers keep such a rule as it is.
    def self.from_rule(rule_hash)
      return new(ends: "never", interval: 1, monthly_by: "day_of_month") if rule_hash.blank?
      rule = IceCube::Rule.from_hash(rule_hash)
      hash = rule.to_hash
      frequency = RULE_TYPES[hash[:rule_type]]
      return nil if frequency.nil? || !representable?(frequency, hash[:validations] || {})

      new(frequency: frequency, interval: hash[:interval] || 1, ends: ends_for(rule),
        monthly_by: hash.dig(:validations, :day_of_week) ? "day_of_week" : "day_of_month",
        ends_on: rule.until_time&.to_date, count: hash[:count])
    end

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
    def self.representable?(frequency, validations)
      allowed = {"daily" => [], "weekly" => %i[day], "monthly" => %i[day_of_month day_of_week],
                 "yearly" => []}
      validations.keys.map(&:to_sym).all? { |key| allowed[frequency].include?(key) } &&
        validations.values.all? { |value| Array(value).size <= 1 }
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
        when "weekly" then starts_at.wday
        when "monthly"
          (monthly_by == "day_of_week") ? [starts_at.wday, nth_weekday(starts_at)] : starts_at.day
        when "yearly" then [starts_at.month, starts_at.day]
        end
      [frequency, interval, (monthly_by if frequency == "monthly"), day]
    end

    def ends_key
      [ends, (ends_on if ends == "on_date"), (count if ends == "after_count")]
    end

    def min_gap
      MIN_GAPS[frequency] * interval
    end

    # Which week of the month the date's weekday falls in. A fifth one doesn't happen every month, so
    # it counts as the last (-1), which does.
    def nth_weekday(date)
      nth = ((date.day - 1) / 7) + 1
      (nth == 5) ? -1 : nth
    end

    private

    def base_rule(starts_at)
      case frequency
      when "daily" then IceCube::Rule.daily(interval)
      when "weekly" then IceCube::Rule.weekly(interval).day(starts_at.wday)
      when "monthly"
        rule = IceCube::Rule.monthly(interval)
        if monthly_by == "day_of_week"
          rule.day_of_week(starts_at.wday => [nth_weekday(starts_at)])
        else
          rule.day_of_month(starts_at.day)
        end
      when "yearly" then IceCube::Rule.yearly(interval)
      end
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
