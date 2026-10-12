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

    it "repeats monthly on the start's date" do
      rule = pattern(frequency: "monthly").to_rule_hash(start, all_day: false)
      expect(occurrences(rule).map(&:to_date).map(&:day)).to all(eq(20))
    end

    it "repeats monthly on the start's nth weekday" do
      rule = pattern(frequency: "monthly", monthly_by: "day_of_week").to_rule_hash(start, all_day: false)
      expect(occurrences(rule).map { |t| [t.wday, ((t.day - 1) / 7) + 1] }).to all(eq([2, 3]))
    end

    it "treats a fifth weekday as the last one, which every month has" do
      fifth_thursday = Time.zone.parse("2026-10-29 19:00")
      rule = pattern(frequency: "monthly", monthly_by: "day_of_week")
        .to_rule_hash(fifth_thursday, all_day: false)
      dates = occurrences(rule, from: fifth_thursday).map(&:to_date)
      expect(dates).to eq([Date.new(2026, 10, 29), Date.new(2026, 11, 26), Date.new(2026, 12, 31),
        Date.new(2027, 1, 28)])
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

  describe ".from_rule" do
    it "reads back each pattern the form makes" do
      [
        pattern(frequency: "daily", interval: 3),
        pattern(frequency: "weekly", ends: "after_count", count: 5),
        pattern(frequency: "monthly", monthly_by: "day_of_week", ends: "on_date",
          ends_on: Date.new(2027, 3, 1)),
        pattern(frequency: "monthly", interval: 2),
        pattern(frequency: "yearly")
      ].each do |original|
        read = described_class.from_rule(original.to_rule_hash(start, all_day: false))
        expect([read.days_key(start), read.ends_key]).to eq([original.days_key(start), original.ends_key])
      end
    end

    it "reads a bare weekly rule as weekly on the start's weekday" do
      read = described_class.from_rule(IceCube::Rule.weekly.to_hash)
      expect(read.days_key(start)).to eq(["weekly", 1, nil, 2])
    end

    it "can't show a weekly rule on several days" do
      expect(described_class.from_rule(IceCube::Rule.weekly.day(:monday, :thursday).to_hash)).to be_nil
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
  end

  describe "validation" do
    it "requires an end date when ending on a date" do
      expect(pattern(frequency: "weekly", ends: "on_date")).not_to be_valid
    end

    it "requires at least two occurrences when ending after a count" do
      expect(pattern(frequency: "weekly", ends: "after_count", count: 1)).not_to be_valid
      expect(pattern(frequency: "weekly", ends: "after_count", count: 2)).to be_valid
    end

    it "requires an interval of at least one" do
      expect(pattern(frequency: "daily", interval: 0)).not_to be_valid
    end

    it "ignores the other fields when the event doesn't repeat" do
      expect(pattern(frequency: "", ends: "bogus", interval: -3)).to be_valid
    end
  end
end
