# frozen_string_literal: true

require "rails_helper"

describe Calendars::Event do
  let(:allow_overlap) { false }
  let(:calendar) { create(:calendar, allow_overlap: allow_overlap) }
  let(:calendar2) { create(:calendar) }

  describe "no_overlap" do
    let!(:existing_event) do
      create(:event, calendar: calendar, starts_at: "2016-04-07 13:00", ends_at: "2016-04-07 15:00")
    end
    let(:event) { Calendars::Event.new(calendar: calendar) }

    context "with no overlap allowed" do
      let(:allow_overlap) { false }

      it "should not set error if no overlap on left" do
        event.assign_attributes(starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00")
        expect_no_error(:no_overlap)
      end

      it "should not set error if no overlap on right" do
        event.assign_attributes(starts_at: "2016-04-07 15:00", ends_at: "2016-04-07 15:30")
        expect_no_error(:no_overlap)
      end

      it "should set error if partial overlap on left" do
        event.assign_attributes(starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:01")
        expect_overlap_error
      end

      it "should set error if partial overlap on right" do
        event.assign_attributes(starts_at: "2016-04-07 14:59", ends_at: "2016-04-07 15:30")
        expect_overlap_error
      end

      it "should set error if full overlap" do
        event.assign_attributes(starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 15:30")
        expect_overlap_error
      end

      it "should set error if interior overlap" do
        event.assign_attributes(starts_at: "2016-04-07 14:30", ends_at: "2016-04-07 14:45")
        expect_overlap_error
      end
    end

    context "with overlap allowed" do
      let(:allow_overlap) { true }

      it "should not set error if overlap" do
        event.assign_attributes(starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:01")
        expect_no_error(:no_overlap)
      end
    end

    def expect_overlap_error
      event.send(:no_overlap)
      expect(event.errors[:base]).to eq(["This event overlaps an existing one"])
    end
  end

  describe "apply_rules" do
    context "with no protocols" do
      let(:event) { Calendars::Event.new(calendar: calendar) }

      it "should not set error" do
        expect_no_error(:apply_rules)
      end
    end

    context "with a protocol" do
      let!(:protocol) { create(:calendar_protocol, calendars: [calendar2], requires_kind: true) }
      let(:event) { Calendars::Event.new(calendar: calendar2) }

      it "should set an error if applicable" do
        event.send(:apply_rules)
        expect(event.errors[:kind]).to eq(["can't be blank"])
      end
    end

    context "with missing starts_at" do
      let!(:protocol) { create(:calendar_protocol, calendars: [calendar2], max_lead_days: 30) }
      let(:event) { Calendars::Event.new(calendar: calendar2) }

      it "should not apply rules since doing so would cause problems" do
        event.save
        expect(event.errors[:starts_at]).to eq(["can't be blank"])
      end
    end
  end

  describe "other validations" do
    describe "can't change start time on not-just-created event after it begins" do
      let(:ends_at) { starts_at + 1.hour }
      let(:privileged_changer) { false }
      let(:event) do
        create(:event, created_at: created_at, starts_at: starts_at, ends_at: ends_at,
                             privileged_changer: privileged_changer)
      end
      subject(:changed_event) do
        event.tap { |r| r.starts_at += 10.minutes } # Attempt to change the start time.
      end

      context "just-created event with start time in past" do
        let(:created_at) { 5.minutes.ago }
        let(:starts_at) { 1.hour.ago }
        it { is_expected.to be_valid }
      end

      context "not-just-created event" do
        let(:created_at) { 2.hours.ago }

        context "start time in future" do
          let(:starts_at) { 1.hour.from_now }
          it { is_expected.to be_valid }
        end

        context "start time in past" do
          let(:starts_at) { 5.minutes.ago }

          context "privileged changer" do
            let(:privileged_changer) { true }
            it { is_expected.to be_valid }
          end

          context "normal changer" do
            it { is_expected.to have_errors(starts_at: "can't be changed after event begins") }
          end
        end
      end
    end

    describe "can't change end time to a time in the past on not-just-created event" do
      let(:starts_at) { 30.minutes.ago }
      let(:ends_at) { starts_at + 1.hour }
      subject(:event) do
        create(:event, created_at: created_at, starts_at: starts_at, ends_at: ends_at).tap do |r|
          r.ends_at = new_ends_at
        end
      end

      context "just-created event" do
        let(:created_at) { 5.minutes.ago }
        let(:new_ends_at) { Time.current - 1.minute }
        it { is_expected.to be_valid }
      end

      context "not-just-created event" do
        let(:created_at) { 2.hours.ago }

        context "new end time in future" do
          let(:new_ends_at) { Time.current + 1.minute }
          it { is_expected.to be_valid }
        end

        context "new end time in past" do
          let(:new_ends_at) { Time.current - 1.minute }
          it { is_expected.to have_errors(ends_at: "can't be changed to a time in the past") }
        end
      end
    end
  end

  describe "meal event handler interactions" do
    let(:meal) { create(:meal, calendars: [create(:calendar)]) }
    let(:event) { meal.events.first }

    before do
      meal.build_events
      meal.save!
    end

    it "should call validate_event and then sync_resourcings" do
      event.starts_at += 1.minute
      expect(meal.event_handler).to receive(:validate_event).with(event)
      expect(meal.event_handler).to receive(:sync_resourcings).with(event)
      event.save!
    end
  end

  def expect_no_error(method)
    event.send(method)
    expect(event.errors).to be_empty
  end
end
