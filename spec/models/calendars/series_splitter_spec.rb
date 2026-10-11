# frozen_string_literal: true

require "rails_helper"

describe Calendars::SeriesSplitter do
  around { |example| Time.use_zone("America/Toronto") { example.run } }

  let(:calendar) { create(:calendar) }
  let(:calendar2) { create(:calendar) }

  # Tuesdays at 7pm. Toronto falls back on 2026-11-01, so the series crosses a DST change.
  let(:series_start) { Time.zone.parse("2026-10-13 19:00") }
  let(:cut) { series_start + 3.weeks }
  let(:rule) { IceCube::Rule.weekly.to_hash }
  let!(:event) do
    create(:event, calendar: calendar, starts_at: series_start, ends_at: series_start + 1.hour,
      recurrence_rule: rule, name: "Book club", note: "Bring snacks")
  end
  let(:eventlet) { event.eventlets.first }
  let(:zero) { Calendars::WallClockShift.new(series_start, series_start) }

  subject(:splitter) { described_class.new(event) }

  def split(start_shift: zero, end_shift: zero)
    splitter.split_at(cut, start_shift: start_shift, end_shift: end_shift)
  end

  def starts(event, upto: series_start + 10.weeks)
    event.reload.schedule.occurrences(upto).map(&:to_time)
  end

  def override_at(occurrence_start, **attrs)
    create(:event_override, event: event, occurrence_start: occurrence_start, **attrs)
  end

  describe "#split_at" do
    it "copies the event's details onto the new series" do
      continuation = split
      expect(continuation).to be_persisted
      expect(continuation).not_to eq(event)
      expect(continuation.attributes.slice(*described_class::COPIED_ATTRIBUTES))
        .to eq(event.attributes.slice(*described_class::COPIED_ATTRIBUTES))
    end

    context "with a series that doesn't end" do
      it "ends the original before the cut and carries on from it, with no occurrence lost or added" do
        original = starts(event)
        continuation = split

        expect(starts(event)).to eq(original.select { |t| t < cut })
        expect(starts(continuation)).to eq(original.select { |t| t >= cut })
        expect(continuation.recurrence_end_date).to be_nil
      end
    end

    context "with a COUNT" do
      let(:rule) { IceCube::Rule.weekly.count(6).to_hash }

      it "gives the new series the occurrences that remain" do
        original = starts(event)
        continuation = split

        expect(starts(event).size).to eq(3)
        expect(starts(continuation)).to eq(original.last(3))
      end
    end

    context "with an UNTIL" do
      let(:rule) { IceCube::Rule.weekly.until(Time.zone.parse("2026-11-24 19:00")).to_hash }

      it "keeps the same last occurrence" do
        original = starts(event)
        continuation = split

        expect(starts(event) + starts(continuation)).to eq(original)
        expect(continuation.recurrence_end_date).to eq(Date.new(2026, 11, 24))
      end

      it "moves the end with the series when the series moves" do
        shift = Calendars::WallClockShift.new(cut, cut + 1.hour)
        continuation = split(start_shift: shift, end_shift: shift)

        expect(starts(continuation).last).to eq(Time.zone.parse("2026-11-24 20:00"))
      end
    end

    it "moves the new series by the start shift, keeping local times across DST" do
      shift = Calendars::WallClockShift.new(cut, cut + 1.day + 1.hour)
      continuation = split(start_shift: shift, end_shift: shift)

      expect(continuation.starts_at).to eq(Time.zone.parse("2026-11-04 20:00"))
      expect(continuation.ends_at).to eq(Time.zone.parse("2026-11-04 21:00"))
      expect(starts(continuation).second).to eq(Time.zone.parse("2026-11-11 20:00"))
      expect(starts(event).last).to eq(series_start + 2.weeks)
    end

    it "changes the new series' duration when only the end shifts" do
      continuation = split(end_shift: Calendars::WallClockShift.new(cut, cut + 30.minutes))

      expect(continuation.starts_at).to eq(cut)
      expect(continuation.ends_at - continuation.starts_at).to eq(90.minutes)
      expect(event.reload.ends_at - event.starts_at).to eq(1.hour)
    end

    context "with the event on two calendars" do
      before do
        Calendars::Eventlet.create!(event_id: event.id, calendar: calendar2, start_offset: 15.minutes.to_i,
          end_offset: 15.minutes.to_i)
      end

      it "gives the new series one eventlet per calendar, with the same offsets" do
        continuation = split

        eventlets = Calendars::Eventlet.where(event_id: continuation.id).order(:calendar_id)
        expect(eventlets.map { |e| [e.calendar_id, e.start_offset, e.end_offset] })
          .to eq([[calendar.id, 0, 0], [calendar2.id, 15.minutes.to_i, 15.minutes.to_i]].sort)
      end
    end

    describe "overrides" do
      let!(:before_cut) { override_at(series_start + 1.week, deleted: true) }
      let!(:moved) do
        override_at(cut + 1.week, starts_at: Time.zone.parse("2026-11-12 10:00"),
          ends_at: Time.zone.parse("2026-11-12 11:00"))
      end
      let!(:deleted) { override_at(cut + 2.weeks, deleted: true) }
      let!(:anchor) { override_at(cut) }
      let!(:calendar_only) do
        create(:eventlet_override, event_override: anchor, eventlet: eventlet,
          start_offset: 30.minutes.to_i, end_offset: 30.minutes.to_i)
      end
      let(:shift) { Calendars::WallClockShift.new(cut, cut + 1.hour) }

      it "leaves the ones before the cut on the original event" do
        split(start_shift: shift, end_shift: shift)
        expect(before_cut.reload.event_id).to eq(event.id)
        expect(before_cut.occurrence_start).to eq(series_start + 1.week)
      end

      it "moves the rest to the new series with keys that match its schedule" do
        continuation = split(start_shift: shift, end_shift: shift)

        [moved, deleted, anchor].each(&:reload)
        expect([moved, deleted, anchor].map(&:event_id).uniq).to eq([continuation.id])
        expect([anchor, moved, deleted].map(&:occurrence_start)).to eq(starts(continuation).first(3))
      end

      it "keeps a moved occurrence at its own time and a deleted one deleted" do
        split(start_shift: shift, end_shift: shift)

        expect(moved.reload.starts_at).to eq(Time.zone.parse("2026-11-12 10:00"))
        expect(deleted.reload).to be_deleted
      end

      it "moves a calendar-only change to the new series' eventlet for that calendar" do
        continuation = split(start_shift: shift, end_shift: shift)

        expect(calendar_only.reload.eventlet.event_id).to eq(continuation.id)
        expect(calendar_only.eventlet.calendar_id).to eq(calendar.id)
        expect(calendar_only.start_offset).to eq(30.minutes.to_i)
      end

      it "updates override records the caller already has loaded" do
        loaded = event.event_overrides.to_a.detect { |o| o.id == moved.id }
        continuation = split(start_shift: shift, end_shift: shift)

        expect(loaded.event_id).to eq(continuation.id)
        expect(loaded.occurrence_start).to eq(moved.reload.occurrence_start)
      end
    end
  end

  describe "#truncate_before" do
    it "ends the series with the previous occurrence and drops later overrides" do
      later = override_at(cut + 1.week, deleted: true)
      earlier = override_at(series_start + 1.week, deleted: true)

      splitter.truncate_before(cut)

      expect(starts(event).last).to eq(series_start + 2.weeks)
      expect(Calendars::EventOverride.where(id: later.id)).to be_empty
      expect(earlier.reload).to be_persisted
    end
  end
end
