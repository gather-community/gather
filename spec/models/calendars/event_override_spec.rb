# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventOverride do
  let(:anchor) { Time.current.tomorrow.midnight }
  let!(:recurring_event) do
    create(:event, starts_at: anchor, ends_at: anchor + 1.hour,
      recurrence_rule: IceCube::Rule.daily.to_hash)
  end

  describe "validations" do
    context "with a valid deletion override" do
      subject { build(:event_override, event: recurring_event, occurrence_start: anchor, deleted: true) }
      it { is_expected.to be_valid }
    end

    context "with valid new times" do
      subject do
        build(:event_override, event: recurring_event, occurrence_start: anchor,
          starts_at: anchor + 2.hours, ends_at: anchor + 3.hours)
      end
      it { is_expected.to be_valid }
    end

    context "with a stub (no times, not deleted) — valid as anchor for EventletOverrides" do
      subject { build(:event_override, event: recurring_event, occurrence_start: anchor) }
      it { is_expected.to be_valid }
    end

    context "when occurrence_start is not in the series" do
      subject do
        build(:event_override, event: recurring_event,
          occurrence_start: anchor + 30.minutes, deleted: true)
      end
      it { is_expected.to be_invalid }
      it { expect(subject.tap(&:valid?).errors[:occurrence_start]).to be_present }
    end

    context "when ends_at is not after starts_at" do
      subject do
        build(:event_override, event: recurring_event, occurrence_start: anchor,
          starts_at: anchor + 2.hours, ends_at: anchor + 1.hour)
      end
      it { is_expected.to be_invalid }
      it { expect(subject.tap(&:valid?).errors[:ends_at]).to be_present }
    end
  end
end
