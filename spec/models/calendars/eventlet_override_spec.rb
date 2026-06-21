# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventletOverride do
  let(:anchor) { Time.current.tomorrow.midnight }
  let!(:recurring_event) do
    create(:event, starts_at: anchor, ends_at: anchor + 1.hour,
      recurrence_rule: IceCube::Rule.daily.to_hash)
  end
  let(:eventlet) { recurring_event.eventlets.first }
  let(:event_override) { create(:event_override, event: recurring_event, occurrence_start: anchor) }

  describe "validations" do
    context "with a valid deletion override" do
      subject { build(:eventlet_override, event_override: event_override, eventlet: eventlet, deleted: true) }
      it { is_expected.to be_valid }
    end

    context "with a valid offset override" do
      subject do
        build(:eventlet_override, event_override: event_override, eventlet: eventlet,
          start_offset: -3600, end_offset: 3600)
      end
      it { is_expected.to be_valid }
    end

    context "when offset exceeds MAX_OFFSET_SECONDS" do
      subject do
        build(:eventlet_override, event_override: event_override, eventlet: eventlet,
          start_offset: Calendars::Eventlet::MAX_OFFSET_SECONDS + 1)
      end
      it { is_expected.to be_invalid }
      it { expect(subject.tap(&:valid?).errors[:start_offset]).to be_present }
    end

    context "when not deleted and no offsets" do
      subject { build(:eventlet_override, event_override: event_override, eventlet: eventlet) }
      it { is_expected.to be_invalid }
      it { expect(subject.tap(&:valid?).errors[:base]).to be_present }
    end

    context "when eventlet belongs to a different event" do
      let(:other_event) { create(:event) }
      let(:other_eventlet) { other_event.eventlets.first }
      subject do
        build(:eventlet_override, event_override: event_override, eventlet: other_eventlet, deleted: true)
      end
      it { is_expected.to be_invalid }
      it { expect(subject.tap(&:valid?).errors[:eventlet]).to be_present }
    end
  end

  describe "#occurrence_start" do
    subject(:elo) { build(:eventlet_override, event_override: event_override, eventlet: eventlet, deleted: true) }
    it "delegates to event_override" do
      expect(elo.occurrence_start).to eq(anchor)
    end
  end
end
