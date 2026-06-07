# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventOverride do
  let(:daily_rule) { IceCube::Rule.daily.to_hash }
  let(:anchor) { Time.current.tomorrow.midnight }

  let!(:recurring_event) do
    create(:event, starts_at: anchor, ends_at: anchor + 1.hour, recurrence_rule: daily_rule)
  end
  let(:eventlet) { recurring_event.eventlets.first }

  describe "validations" do
    context "with a valid deletion override" do
      subject(:override) do
        build(:event_override, eventlet: eventlet, occurrence_start: anchor, deleted: true)
      end

      it { is_expected.to be_valid }
    end

    context "with a valid move override" do
      subject(:override) do
        build(:event_override, eventlet: eventlet, occurrence_start: anchor,
          starts_at: anchor + 2.hours, ends_at: anchor + 3.hours)
      end

      it { is_expected.to be_valid }
    end

    context "when occurrence_start is not a valid occurrence in the series" do
      subject(:override) do
        build(:event_override, eventlet: eventlet,
          occurrence_start: anchor + 30.minutes, deleted: true)
      end

      it "is invalid" do
        is_expected.to be_invalid
        expect(subject.errors[:occurrence_start]).to be_present
      end
    end

    context "when ends_at is not after starts_at" do
      subject(:override) do
        build(:event_override, eventlet: eventlet, occurrence_start: anchor,
          starts_at: anchor + 2.hours, ends_at: anchor + 1.hour)
      end

      it "is invalid" do
        is_expected.to be_invalid
        expect(subject.errors[:ends_at]).to be_present
      end
    end

    context "when not deleted and no times provided" do
      subject(:override) do
        build(:event_override, eventlet: eventlet, occurrence_start: anchor, deleted: false)
      end

      it "is invalid" do
        is_expected.to be_invalid
        expect(subject.errors[:base]).to be_present
      end
    end
  end
end
