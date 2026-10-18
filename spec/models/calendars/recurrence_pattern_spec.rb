# frozen_string_literal: true

require "rails_helper"

describe Calendars::RecurrencePattern do
  around { |example| Time.use_zone("America/Toronto") { example.run } }

  # Tuesday, the third Tuesday of the month.
  let(:start) { Time.zone.parse("2026-10-20 19:00") }

  def pattern(**attrs)
    described_class.new(interval: 1, ends: "never", monthly_by: "day_of_month", **attrs)
  end

  def occurrences(rule_hash, from: start, count: 4)
    schedule = IceCube::Schedule.new(from) { |s| s.add_recurrence_rule(IceCube::Rule.from_hash(rule_hash)) }
    schedule.first(count).map(&:to_time)
  end

  describe "#to_rule_hash" do
    it "is nil when the event doesn't repeat" do
      expect(pattern(frequency: "").to_rule_hash(start, all_day: false)).to be_nil
    end

    it "repeats daily, every N days" do
      rule = pattern(frequency: "daily", interval: 2).to_rule_hash(start, all_day: false)
      expect(occurrences(rule)).to eq([start, start + 2.days, start + 4.days, start + 6.days])
    end

    it "repeats weekly on the start's weekday, which is the first occurrence" do
      rule = pattern(frequency: "weekly", interval: 2).to_rule_hash(start, all_day: false)
      expect(occurrences(rule)).to eq([start, start + 2.weeks, start + 4.weeks, start + 6.weeks])
    end

    it "repeats weekly on the chosen weekdays, always including the start's" do
      # Thursday and Saturday chosen; the start, a Tuesday, is added.
      rule = pattern(frequency: "weekly", weekdays: %w[4 6]).to_rule_hash(start, all_day: false)
      expect(occurrences(rule)).to eq([start, start + 2.days, start + 4.days, start + 1.week])
    end

    it "repeats monthly on the start's date" do
      rule = pattern(frequency: "monthly").to_rule_hash(start, all_day: false)
      expect(occurrences(rule).map(&:to_date).map(&:day)).to all(eq(20))
    end

    it "repeats monthly on the start's nth weekday" do
      rule = pattern(frequency: "monthly", monthly_by: "day_of_week").to_rule_hash(start, all_day: false)
      expect(occurrences(rule).map { |t| [t.wday, ((t.day - 1) / 7) + 1] }).to all(eq([2, 3]))
    end

    it "repeats monthly on the last of the start's weekday, which every month has" do
      fifth_thursday = Time.zone.parse("2026-10-29 19:00")
      rule = pattern(frequency: "monthly", monthly_by: "last_day_of_week")
        .to_rule_hash(fifth_thursday, all_day: false)
      dates = occurrences(rule, from: fifth_thursday).map(&:to_date)
      expect(dates).to eq([Date.new(2026, 10, 29), Date.new(2026, 11, 26), Date.new(2026, 12, 31),
        Date.new(2027, 1, 28)])
    end

    it "repeats monthly on the last day of the month, which every month has" do
      halloween = Time.zone.parse("2026-10-31 19:00")
      rule = pattern(frequency: "monthly", monthly_by: "last_day_of_month")
        .to_rule_hash(halloween, all_day: false)
      expect(occurrences(rule, from: halloween).map(&:to_date))
        .to eq([Date.new(2026, 10, 31), Date.new(2026, 11, 30), Date.new(2026, 12, 31),
          Date.new(2027, 1, 31)])
    end

    it "repeats yearly on the start's date" do
      rule = pattern(frequency: "yearly").to_rule_hash(start, all_day: false)
      expect(occurrences(rule, count: 2)).to eq([start, start + 1.year])
    end

    it "ends on a date, keeping an occurrence that falls on it" do
      rule = pattern(frequency: "weekly", ends: "on_date", ends_on: "2026-11-03")
        .to_rule_hash(start, all_day: false)
      expect(occurrences(rule, count: 10)).to eq([start, start + 1.week, start + 2.weeks])
    end

    it "keeps the local time of the end across a DST change" do
      rule = pattern(frequency: "weekly", ends: "on_date", ends_on: Date.new(2026, 11, 10))
        .to_rule_hash(start, all_day: false)
      expect(occurrences(rule, count: 10).last).to eq(Time.zone.parse("2026-11-10 19:00"))
    end

    it "ends on a date for an all-day series" do
      day = start.midnight
      rule = pattern(frequency: "daily", ends: "on_date", ends_on: day.to_date + 2)
        .to_rule_hash(day, all_day: true)
      expect(occurrences(rule, from: day, count: 10)).to eq([day, day + 1.day, day + 2.days])
    end

    it "ends after a number of occurrences" do
      rule = pattern(frequency: "daily", ends: "after_count", count: "3").to_rule_hash(start, all_day: false)
      expect(occurrences(rule, count: 10).size).to eq(3)
    end
  end

  describe "#ends_on" do
    it "reads the date picker's text in the locale's format" do
      I18n.with_locale(:de) do
        expect(pattern(ends: "on_date", ends_on: "Di 3. Mär 2026").ends_on).to eq(Date.new(2026, 3, 3))
      end
      expect(pattern(ends: "on_date", ends_on: "Nov 03 2026").ends_on).to eq(Date.new(2026, 11, 3))
    end
  end

  describe ".from_rule" do
    it "reads back each pattern the form makes" do
      [
        pattern(frequency: "daily", interval: 3),
        pattern(frequency: "weekly", ends: "after_count", count: 5),
        pattern(frequency: "weekly", weekdays: %w[0 2 5], interval: 2),
        pattern(frequency: "monthly", monthly_by: "day_of_week", ends: "on_date",
          ends_on: Date.new(2027, 3, 1)),
        pattern(frequency: "monthly", monthly_by: "last_day_of_week"),
        pattern(frequency: "monthly", monthly_by: "last_day_of_month"),
        pattern(frequency: "monthly", interval: 2),
        pattern(frequency: "yearly")
      ].each do |original|
        read = described_class.from_rule(original.to_rule_hash(start, all_day: false))
        expect([read.days_key(start), read.ends_key]).to eq([original.days_key(start), original.ends_key])
      end
    end

    it "reads a bare weekly rule as weekly on the start's weekday" do
      read = described_class.from_rule(IceCube::Rule.weekly.to_hash)
      expect(read.days_key(start)).to eq(["weekly", 1, nil, [2]])
    end

    it "reads a weekly rule on several days" do
      read = described_class.from_rule(IceCube::Rule.weekly.day(:monday, :thursday).to_hash)
      expect(read.weekdays).to eq([1, 4])
    end

    it "reads a monthly rule on a fifth weekday, which only older series have, as the last" do
      read = described_class.from_rule(IceCube::Rule.monthly.day_of_week(thursday: [-1]).to_hash)
      expect(read.monthly_by).to eq("last_day_of_week")
    end

    it "can't show a monthly rule on several dates" do
      expect(described_class.from_rule(IceCube::Rule.monthly.day_of_month(1, 15).to_hash)).to be_nil
    end

    it "reads no rule as not repeating" do
      expect(described_class.from_rule(nil)).not_to be_recurring
    end
  end

  describe "#days_key" do
    it "changes with the start's weekday for a weekly series, but not its time" do
      weekly = pattern(frequency: "weekly")
      expect(weekly.days_key(start + 1.hour)).to eq(weekly.days_key(start))
      expect(weekly.days_key(start + 1.day)).not_to eq(weekly.days_key(start))
    end

    it "tells the 4th weekday from the last" do
      fourth_and_last = Time.zone.parse("2026-10-27 19:00")
      expect(pattern(frequency: "monthly", monthly_by: "day_of_week").days_key(fourth_and_last))
        .not_to eq(pattern(frequency: "monthly", monthly_by: "last_day_of_week").days_key(fourth_and_last))
    end
  end

  describe ".monthly_by_options" do
    it "offers the date and the nth weekday early in the month" do
      expect(described_class.monthly_by_options(Date.new(2026, 10, 20))).to eq(%w[day_of_month day_of_week])
    end

    it "offers both the 4th and the last weekday in the last week, when it's the 4th" do
      expect(described_class.monthly_by_options(Date.new(2026, 10, 27)))
        .to eq(%w[day_of_month day_of_week last_day_of_week])
    end

    it "offers only the last for a fifth weekday, which most months lack" do
      expect(described_class.monthly_by_options(Date.new(2026, 10, 29)))
        .to eq(%w[day_of_month last_day_of_week])
    end

    it "offers the last day of the month on the last day" do
      expect(described_class.monthly_by_options(Date.new(2026, 10, 31)))
        .to eq(%w[day_of_month last_day_of_month last_day_of_week])
      expect(described_class.monthly_by_options(Date.new(2027, 2, 28))).to include("last_day_of_month")
      expect(described_class.monthly_by_options(Date.new(2026, 10, 30))).not_to include("last_day_of_month")
    end
  end

  describe ".closest_monthly_by" do
    it "keeps a choice the date allows" do
      expect(described_class.closest_monthly_by("day_of_week", Date.new(2026, 10, 27))).to eq("day_of_week")
    end

    it "switches between the 4th and the last when only the other is allowed" do
      expect(described_class.closest_monthly_by("day_of_week",
        Date.new(2026, 10, 29))).to eq("last_day_of_week")
      expect(described_class.closest_monthly_by("last_day_of_week",
        Date.new(2026, 10, 20))).to eq("day_of_week")
    end
  end

  describe "#min_gap" do
    it "is the interval's length for a single weekday" do
      expect(pattern(frequency: "weekly", interval: 2).min_gap(start)).to eq(14.days)
    end

    it "is the closest two days for several, counting the wrap into the next week" do
      # Tuesday and Thursday: 2 days apart. Sunday and Saturday every other week: 6 days apart in the
      # same week, then 8 from Saturday to the Sunday after the skipped week.
      expect(pattern(frequency: "weekly", weekdays: %w[4]).min_gap(start)).to eq(2.days)
      saturday = start + 4.days
      expect(pattern(frequency: "weekly", weekdays: %w[0], interval: 2).min_gap(saturday)).to eq(6.days)
    end
  end

  describe "validation" do
    it "requires an end date when ending on a date" do
      expect(pattern(frequency: "weekly", ends: "on_date")).not_to be_valid
    end

    it "requires at least two occurrences when ending after a count" do
      expect(pattern(frequency: "weekly", ends: "after_count", count: 1)).not_to be_valid
      expect(pattern(frequency: "weekly", ends: "after_count", count: 2)).to be_valid
    end

    it "requires real weekdays" do
      expect(pattern(frequency: "weekly", weekdays: %w[7])).not_to be_valid
    end

    it "requires whole numbers as submitted, rather than rounding them" do
      expect(pattern(frequency: "daily", interval: "1.5")).not_to be_valid
      expect(pattern(frequency: "daily", interval: "abc")).not_to be_valid
      expect(pattern(frequency: "daily", ends: "after_count", count: "2.5")).not_to be_valid
      expect(pattern(frequency: "daily", interval: "2", ends: "after_count", count: "3")).to be_valid
    end

    it "requires an interval of at least one" do
      expect(pattern(frequency: "daily", interval: 0)).not_to be_valid
    end

    it "ignores the other fields when the event doesn't repeat" do
      expect(pattern(frequency: "", ends: "bogus", interval: -3)).to be_valid
    end
  end
end
