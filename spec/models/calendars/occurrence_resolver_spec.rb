# frozen_string_literal: true

require "rails_helper"

describe Calendars::OccurrenceResolver do
  let(:calendar) { create(:calendar) }
  let(:base_eventlet) { event.eventlets.first }
  subject(:resolved) { described_class.new(base_eventlet, occurrence_param).resolve }

  context "with a non-recurring event" do
    let(:event) do
      create(:event, calendar: calendar,
        starts_at: "2026-06-08 14:00", ends_at: "2026-06-08 15:00")
    end

    context "with no occurrence param" do
      let(:occurrence_param) { nil }

      it "returns the eventlet itself" do
        expect(resolved).to eq(base_eventlet)
      end
    end

    context "with an occurrence param (nonsensical)" do
      let(:occurrence_param) { Time.zone.parse("2026-06-08 14:00").to_i.to_s }

      it "returns nil" do
        expect(resolved).to be_nil
      end
    end
  end

  context "with a recurring event" do
    # Weekly from Monday 2026-06-08 14:00. Second occurrence is Monday 2026-06-15 14:00.
    let(:event) do
      create(:event, calendar: calendar,
        starts_at: "2026-06-08 14:00", ends_at: "2026-06-08 15:00",
        recurrence_rule: IceCube::Rule.weekly.to_hash)
    end
    let(:occ2) { Time.zone.parse("2026-06-15 14:00") }
    let(:occurrence_param) { occ2.to_i.to_s }

    context "with no occurrence param" do
      let(:occurrence_param) { nil }

      it "returns the first occurrence" do
        expect(resolved.occurrence_start).to eq(event.starts_at)
        expect(resolved.starts_at).to be_within(1.second).of(event.starts_at)
      end
    end

    context "with a valid occurrence param" do
      it "returns a transient occurrence at that time, linked to the base eventlet" do
        expect(resolved).not_to be_persisted
        expect(resolved.occurrence_start).to eq(occ2)
        expect(resolved.starts_at).to be_within(1.second).of(occ2)
        expect(resolved.ends_at).to be_within(1.second).of(occ2 + 1.hour)
        expect(resolved.linkable).to eq(base_eventlet)
      end
    end

    context "with an occurrence param not in the series" do
      let(:occurrence_param) { Time.zone.parse("2026-06-16 14:00").to_i.to_s }

      it "returns nil" do
        expect(resolved).to be_nil
      end
    end

    context "when the occurrence is deleted by an EventOverride" do
      before { create(:event_override, event: event, occurrence_start: occ2, deleted: true) }

      it "returns nil" do
        expect(resolved).to be_nil
      end
    end

    context "when the occurrence is deleted by an EventletOverride for this calendar" do
      before do
        eo = create(:event_override, event: event, occurrence_start: occ2)
        create(:eventlet_override, event_override: eo, eventlet: base_eventlet, deleted: true)
      end

      it "returns nil" do
        expect(resolved).to be_nil
      end
    end

    context "when the occurrence is moved by an EventOverride" do
      let(:new_start) { Time.zone.parse("2026-06-16 09:00") }
      let(:new_end) { Time.zone.parse("2026-06-16 10:00") }
      before do
        create(:event_override, event: event, occurrence_start: occ2,
          starts_at: new_start, ends_at: new_end)
      end

      it "returns the occurrence at the moved time but preserves the original occurrence_start" do
        expect(resolved.starts_at).to be_within(1.second).of(new_start)
        expect(resolved.ends_at).to be_within(1.second).of(new_end)
        expect(resolved.occurrence_start).to eq(occ2)
      end
    end

    context "when an EventletOverride shifts the display time" do
      before do
        eo = create(:event_override, event: event, occurrence_start: occ2)
        create(:eventlet_override, event_override: eo, eventlet: base_eventlet,
          start_offset: -3600, end_offset: -3600)
      end

      it "applies the offset" do
        expect(resolved.starts_at).to be_within(1.second).of(occ2 - 1.hour)
      end
    end
  end
end
