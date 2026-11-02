# frozen_string_literal: true

require "rails_helper"

describe Calendars::WallClockShift do
  # Toronto falls back on Sunday 2026-11-01 (2am EDT → 1am EST).
  around { |example| Time.use_zone("America/Toronto") { example.run } }

  def t(str)
    Time.zone.parse(str)
  end

  it "shifts within a day" do
    shift = described_class.new(t("2026-10-13 19:00"), t("2026-10-13 20:30"))
    expect(shift.apply(t("2026-10-20 19:00"))).to eq(t("2026-10-20 20:30"))
  end

  it "shifts across days" do
    shift = described_class.new(t("2026-10-13 19:00"), t("2026-10-15 18:00"))
    expect(shift.apply(t("2026-10-20 19:00"))).to eq(t("2026-10-22 18:00"))
  end

  it "keeps the local time of day across a DST change" do
    shift = described_class.new(t("2026-10-27 19:00"), t("2026-10-27 20:00"))
    shifted = shift.apply(t("2026-11-03 19:00"))
    expect(shifted).to eq(t("2026-11-03 20:00"))
    expect(shifted.utc_offset).to eq(-5.hours)
  end

  it "shifts across midnight on a DST night without landing an hour off" do
    # 11pm → 1am next day is "one day later, 22 hours earlier". Applied to the night of the change,
    # a fixed 22-hour subtraction would land at midnight or 2am rather than 1am.
    shift = described_class.new(t("2026-10-24 23:00"), t("2026-10-25 01:00"))
    expect(shift.apply(t("2026-10-31 23:00"))).to eq(t("2026-11-01 01:00"))
  end

  it "carries an earlier time of day into the previous day" do
    # Measured at 11:30pm → 12:30am, applied to a 10:30pm time: 10:30pm minus 23 hours is the
    # previous day, plus the one day, giving 11:30pm on the same date.
    shift = described_class.new(t("2026-10-13 23:30"), t("2026-10-14 00:30"))
    expect(shift.apply(t("2026-10-13 22:30"))).to eq(t("2026-10-13 23:30"))
  end

  it "carries a later time of day into the next day" do
    shift = described_class.new(t("2026-10-13 19:00"), t("2026-10-13 20:00"))
    expect(shift.apply(t("2026-10-20 23:59:59"))).to eq(t("2026-10-21 00:59:59"))
  end

  it "shifts earlier" do
    shift = described_class.new(t("2026-10-13 19:00"), t("2026-10-06 17:00"))
    expect(shift.apply(t("2026-11-10 19:00"))).to eq(t("2026-11-03 17:00"))
  end

  describe "#zero?" do
    it "is true for no change" do
      expect(described_class.new(t("2026-10-13 19:00"), t("2026-10-13 19:00"))).to be_zero
    end

    it "is false for any change" do
      expect(described_class.new(t("2026-10-13 19:00"), t("2026-10-13 19:01"))).not_to be_zero
    end
  end
end
