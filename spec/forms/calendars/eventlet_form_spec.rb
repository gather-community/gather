# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventletForm do
  let(:admin) { create(:admin) }
  let(:calendar) { create(:calendar, allow_overlap: true) }
  let(:calendar2) { create(:calendar, allow_overlap: true) }

  # Next week so the past-change restriction doesn't interfere.
  let(:base_start) { Time.zone.now.next_week.midnight + 12.hours }
  let(:base_end) { base_start + 1.hour }

  let(:eventlet) { create(:eventlet, calendar: calendar, starts_at: base_start, ends_at: base_end) }
  let(:event) { eventlet.event }

  def submit(params)
    described_class.new(eventlet: eventlet, current_user: admin, params: params)
  end

  describe "all calendars + whole series" do
    it "moves the event itself" do
      form = submit(calendar_scope: "all", series_scope: "series",
        starts_at: (base_start + 2.hours).iso8601, ends_at: (base_end + 2.hours).iso8601)

      expect(form.save).to be(true)
      expect(event.reload.starts_at).to eq(base_start + 2.hours)
      expect(event.ends_at).to eq(base_end + 2.hours)
      expect(eventlet.reload.start_offset).to eq(0)
    end

    it "accounts for the dragged eventlet's existing offsets" do
      eventlet.update!(start_offset: -1.hour.to_i, end_offset: -1.hour.to_i)

      # The eventlet currently displays an hour before the event; dropping it at base_start means
      # the event itself must land an hour later.
      form = submit(calendar_scope: "all", series_scope: "series",
        starts_at: base_start.iso8601, ends_at: base_end.iso8601)

      expect(form.save).to be(true)
      expect(event.reload.starts_at).to eq(base_start + 1.hour)
      expect(eventlet.reload.starts_at).to eq(base_start)
    end
  end

  describe "this calendar + whole series" do
    it "shifts only this eventlet's offsets, leaving the event alone" do
      form = submit(calendar_scope: "this", series_scope: "series",
        starts_at: (base_start + 30.minutes).iso8601, ends_at: (base_end + 45.minutes).iso8601)

      expect(form.save).to be(true)
      expect(eventlet.reload.start_offset).to eq(30.minutes.to_i)
      expect(eventlet.end_offset).to eq(45.minutes.to_i)
      expect(event.reload.starts_at).to eq(base_start)
    end

    it "leaves other calendars' eventlets untouched" do
      other = Calendars::Eventlet.create!(event_id: event.id, calendar: calendar2)

      form = submit(calendar_scope: "this", series_scope: "series",
        starts_at: (base_start + 30.minutes).iso8601, ends_at: (base_end + 30.minutes).iso8601)

      expect(form.save).to be(true)
      expect(other.reload.start_offset).to eq(0)
    end

    it "rejects a drag beyond the max offset" do
      too_far = Calendars::Eventlet::MAX_OFFSET_SECONDS + 1.hour
      form = submit(calendar_scope: "this", series_scope: "series",
        starts_at: (base_start + too_far).iso8601, ends_at: (base_end + too_far).iso8601)

      expect(form.save).to be(false)
      expect(form.errors[:start_offset]).to be_present
    end
  end

  context "with a recurring event" do
    before { event.update!(recurrence_rule: IceCube::Rule.weekly.to_hash) }

    let(:occurrence) { base_start + 1.week }

    describe "all calendars + this occurrence" do
      it "creates an EventOverride and leaves the series anchor alone" do
        form = submit(calendar_scope: "all", series_scope: "occurrence",
          occurrence_start: occurrence.to_i,
          starts_at: (occurrence + 2.hours).iso8601, ends_at: (occurrence + 3.hours).iso8601)

        expect(form.save).to be(true)
        override = event.event_overrides.sole
        expect(override.occurrence_start).to eq(occurrence)
        expect(override.starts_at).to eq(occurrence + 2.hours)
        expect(event.reload.starts_at).to eq(base_start)
      end
    end

    describe "this calendar + this occurrence" do
      it "creates an anchor EventOverride plus an EventletOverride with offsets" do
        form = submit(calendar_scope: "this", series_scope: "occurrence",
          occurrence_start: occurrence.to_i,
          starts_at: (occurrence + 30.minutes).iso8601, ends_at: (occurrence + 90.minutes).iso8601)

        expect(form.save).to be(true)

        anchor = event.event_overrides.sole
        expect(anchor.occurrence_start).to eq(occurrence)
        # The anchor exists only to hold occurrence identity; it carries no time change of its own.
        expect(anchor.starts_at).to be_nil

        override = anchor.eventlet_overrides.sole
        expect(override.eventlet_id).to eq(eventlet.id)
        expect(override.start_offset).to eq(30.minutes.to_i)
        expect(override.end_offset).to eq(30.minutes.to_i)

        expect(event.reload.starts_at).to eq(base_start)
        expect(eventlet.reload.start_offset).to eq(0)
      end

      it "reuses an existing EventOverride rather than creating a second one" do
        existing = event.event_overrides.create!(occurrence_start: occurrence,
          starts_at: occurrence + 1.hour, ends_at: occurrence + 2.hours)

        form = submit(calendar_scope: "this", series_scope: "occurrence",
          occurrence_start: occurrence.to_i,
          starts_at: (occurrence + 90.minutes).iso8601, ends_at: (occurrence + 150.minutes).iso8601)

        expect(form.save).to be(true)
        expect(event.event_overrides.count).to eq(1)
        # Offsets are relative to the already-moved occurrence, not its scheduled slot.
        expect(existing.eventlet_overrides.sole.start_offset).to eq(30.minutes.to_i)
      end

      it "rejects an occurrence that isn't in the series" do
        form = submit(calendar_scope: "this", series_scope: "occurrence",
          occurrence_start: (occurrence + 1.day).to_i,
          starts_at: (occurrence + 1.day).iso8601, ends_at: (occurrence + 1.day + 1.hour).iso8601)

        expect(form.save).to be(false)
        expect(form.errors[:occurrence_start]).to be_present
      end
    end

    it "requires an occurrence_start when changing a single occurrence" do
      form = submit(calendar_scope: "this", series_scope: "occurrence",
        starts_at: base_start.iso8601, ends_at: base_end.iso8601)

      expect(form.save).to be(false)
      expect(form.errors[:occurrence_start]).to be_present
    end
  end

  describe "validations" do
    it "rejects an end before the start" do
      form = submit(calendar_scope: "this", series_scope: "series",
        starts_at: base_end.iso8601, ends_at: base_start.iso8601)

      expect(form.save).to be(false)
      expect(form.errors[:ends_at]).to include("must be after start time")
    end

    it "rejects an unknown scope" do
      form = submit(calendar_scope: "sideways", series_scope: "series",
        starts_at: base_start.iso8601, ends_at: base_end.iso8601)

      expect(form.save).to be(false)
      expect(form.errors[:calendar_scope]).to be_present
    end

    it "rejects overlapping eventlets on a calendar that disallows overlap" do
      calendar.update!(allow_overlap: false)
      create(:eventlet, calendar: calendar, starts_at: base_start + 3.hours,
        ends_at: base_start + 4.hours)

      form = submit(calendar_scope: "this", series_scope: "series",
        starts_at: (base_start + 3.hours).iso8601, ends_at: (base_start + 4.hours).iso8601)

      expect(form.save).to be(false)
      expect(form.errors[:base]).to include("This event overlaps an existing one")
    end
  end
end
