# frozen_string_literal: true

require "rails_helper"

describe Calendars::Event do
  let(:allow_overlap) { false }
  let(:calendar) { create(:calendar, allow_overlap: allow_overlap) }
  let(:calendar2) { create(:calendar) }

  it "has a valid factory" do
    create(:event)
    create(:event, group: create(:group))
  end

  describe "eventlet sync" do
    it "syncs eventlet on create and update" do
      event = create(:event, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00")

      expect(event.eventlets.size).to eq(1)

      eventlet = event.eventlets.first
      expect(eventlet.event_id).to eq(event.id)
      expect(eventlet.calendar_id).to eq(event.calendar_id)
      expect(eventlet.cluster_id).to eq(event.cluster_id)
      expect(eventlet.starts_at).to eq("2016-04-07 12:00")
      expect(eventlet.ends_at).to eq("2016-04-07 13:00")

      event.update!(starts_at: "2016-04-07 13:00", ends_at: "2016-04-07 14:00")
      expect(eventlet.starts_at).to eq("2016-04-07 13:00")
      expect(eventlet.ends_at).to eq("2016-04-07 14:00")

      expect(event.eventlets.size).to eq(1)

      # Ensure that references still intact
      eventlet = event.eventlets.first.reload
      expect(eventlet.starts_at).to eq("2016-04-07 13:00")
      expect(eventlet.ends_at).to eq("2016-04-07 14:00")
    end
  end

  describe "normalization" do
    let(:event) { build(:event, submitted) }

    describe "all day events" do
      context "with all_day false" do
        let(:submitted) { {all_day: false, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00"} }

        it do
          event.validate
          expect(event.all_day).to be(false)
          expect(event.starts_at.to_fs(:default)).to eq("2016-04-07T12:00:00")
          expect(event.ends_at.to_fs(:default)).to eq("2016-04-07T13:00:00")
        end
      end

      context "with all_day true" do
        before do
          allow(event).to receive(:rule_set).and_return(double(timed_events_only?: timed_only, errors: []))
        end

        context "with calendar permitting all day events" do
          let(:timed_only) { false }
          let(:submitted) { {all_day: true, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00"} }

          it do
            event.validate
            expect(event.all_day).to be(true)
            expect(event.starts_at.to_fs(:default)).to eq("2016-04-07T00:00:00")
            expect(event.ends_at.to_fs(:default)).to eq("2016-04-07T23:59:59")
          end
        end

        context "with calendar not permitting all day events" do
          let(:timed_only) { true }
          let(:submitted) { {all_day: true, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00"} }

          it do
            event.validate
            expect(event.all_day).to be(false)
            expect(event.starts_at.to_fs(:default)).to eq("2016-04-07T12:00:00")
            expect(event.ends_at.to_fs(:default)).to eq("2016-04-07T13:00:00")
          end
        end
      end
    end
  end

  describe "validation" do
    describe "creator_id presence" do
      context "when not a meal event" do
        it "should not error if creator present" do
          event = build(:event, creator_id: create(:user).id)
          expect(event).to be_valid
        end

        it "should error if creator not present" do
          event = build(:event, creator_id: nil)
          expect(event).to have_errors(creator_id: "can't be blank")
        end
      end

      context "when meal event" do
        it "should not error if creator not present" do
          meal = create(:meal)
          event = build(:event, meal: meal, creator: nil, kind: "_meal", starts_at: meal.served_at, ends_at: meal.served_at + 1.hour)
          expect(event).to be_valid
        end

        # We don't need to test what happens if creator and meal_id are present since this is not possible
        # in the UI and the db constraint will take care of it.
      end
    end

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

  describe "location" do
    let(:calendar) { create(:calendar, name: "Fun Room") }
    subject(:location) { event.location }

    context "with persisted event and no explicit location" do
      let(:event) { create(:event, calendar: calendar) }

      it "returns calendar name as location" do
        expect(event.location).to eq("Fun Room")
      end
    end

    context "with persisted event but explicit location" do
      let(:event) { create(:event, calendar: calendar, location: "Martian surface") }

      it "returns explicit location" do
        expect(event.location).to eq("Martian surface")
      end
    end

    context "with unpersisted event and explicit location" do
      let(:event) { build(:event, calendar: calendar, location: "Martian surface") }

      it "returns explicit location" do
        expect(event.location).to eq("Martian surface")
      end
    end

    context "with unpersisted event and no explicit location" do
      let(:event) { build(:event, calendar: calendar, location: nil) }

      it "returns nil" do
        expect(event.location).to be_nil
      end
    end
  end

  def expect_no_error(method)
    event.send(method)
    expect(event.errors).to be_empty
  end
end
