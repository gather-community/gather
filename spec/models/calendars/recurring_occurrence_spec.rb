# frozen_string_literal: true

require "rails_helper"

describe Calendars::RecurringOccurrence do
  let(:base_time) { Time.zone.parse("2026-06-08 10:00") }
  let(:occ_starts_at) { base_time + 1.week }
  let(:occ_ends_at) { occ_starts_at + 1.hour }
  let(:eventlet) { create(:eventlet, starts_at: base_time, ends_at: base_time + 1.hour) }
  subject(:occurrence) { described_class.new(eventlet, occ_starts_at, occ_ends_at) }

  it "returns the occurrence starts_at and ends_at" do
    expect(occurrence.starts_at).to eq(occ_starts_at)
    expect(occurrence.ends_at).to eq(occ_ends_at)
  end

  it "delegates name to eventlet" do
    expect(occurrence.name).to eq(eventlet.name)
  end

  it "delegates calendar and calendar_id to eventlet" do
    expect(occurrence.calendar).to eq(eventlet.calendar)
    expect(occurrence.calendar_id).to eq(eventlet.calendar_id)
  end

  it "delegates creator and creator_id to eventlet" do
    expect(occurrence.creator).to eq(eventlet.creator)
    expect(occurrence.creator_id).to eq(eventlet.creator_id)
  end

  it "delegates event and event_id to eventlet" do
    expect(occurrence.event).to eq(eventlet.event)
    expect(occurrence.event_id).to eq(eventlet.event_id)
  end

  describe "#id and #uid" do
    it "returns event_id and occurrence timestamp joined by underscore" do
      expected = "#{eventlet.event_id}_#{occ_starts_at.to_i}"
      expect(occurrence.id).to eq(expected)
      expect(occurrence.uid).to eq(expected)
    end

    it "is unique for different occurrence times on the same event" do
      later = described_class.new(eventlet, occ_starts_at + 1.week, occ_ends_at + 1.week)
      expect(occurrence.id).not_to eq(later.id)
    end
  end

  describe "#persisted?" do
    it "returns true because the underlying event exists in the DB" do
      expect(occurrence).to be_persisted
    end
  end

  describe "#future?" do
    it "is true when starts_at is in the future" do
      future = described_class.new(eventlet, 1.hour.from_now, 2.hours.from_now)
      expect(future).to be_future
    end

    it "is false when starts_at is in the past" do
      past = described_class.new(eventlet, 1.hour.ago, 30.minutes.ago)
      expect(past).not_to be_future
    end
  end

  describe "#single_day?" do
    it "is true when starts_at and ends_at are on the same date" do
      expect(occurrence).to be_single_day
    end

    it "is false when they span multiple days" do
      multi = described_class.new(eventlet, occ_starts_at, occ_starts_at + 2.days)
      expect(multi).not_to be_single_day
    end
  end

  describe "duration helpers" do
    it "returns correct seconds" do
      expect(occurrence.seconds).to eq(1.hour)
    end

    it "returns correct minutes" do
      expect(occurrence.minutes).to eq(60)
    end

    it "returns correct days" do
      expect(occurrence.days).to eq(1)
    end
  end
end
