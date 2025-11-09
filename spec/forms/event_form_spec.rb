# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventForm do
  let(:allow_overlap) { false }
  let(:current_user) { create(:user) }
  let(:calendar) { create(:calendar, allow_overlap: allow_overlap) }
  let(:calendar2) { create(:calendar) }

  def build_event_form(calendar:, action: :create, id: nil, all_day: false, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00", guidelines_ok: "1")
    Calendars::EventForm.new(
      action: action,
      current_user: current_user,
      id: id,
      params: {
        calendar_id: calendar.id,
        all_day: all_day,
        starts_at: starts_at,
        ends_at: ends_at,
        name: "Test Event",
        guidelines_ok: guidelines_ok
      }
    )
  end

  describe "parsing starts_at and ends_at" do
    context "when starts_at and ends_at are provided" do
      let(:event_form) { build_event_form(action: :edit, calendar: calendar, starts_at: "2016-04-07 14:30", ends_at: "2016-04-07 16:45") }

      it "should parse and use the provided values" do
        expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-07T14:30:00")
      end
    end

    context "when ends_at is before starts_at" do
      let(:event_form) { build_event_form(action: :new, calendar: calendar, starts_at: "2016-04-07 14:30", ends_at: "2016-04-07 13:45") }

      it "should not alter ends_at if it's before starts_at" do
        expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-07T14:30:00")
        expect(event_form.ends_at.to_fs(:default)).to eq("2016-04-07T13:45:00")
      end
    end
  end


  describe "setting starts_at and ends_at" do
    context "when action is :new" do
      context "when starts_at and ends_at are not provided" do
        let(:event_form) { build_event_form(action: :new, calendar: calendar, starts_at: nil, ends_at: nil) }

        around do |example|
          Timecop.freeze(Time.zone.parse("2016-04-01 10:00")) do
            example.run
          end
        end

        it "should set default values (1 week from now at 5pm and 6pm)" do
          expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-08T17:00:00")
          expect(event_form.ends_at.to_fs(:default)).to eq("2016-04-08T18:00:00")
        end
      end

      context "when rule_set has fixed start and end times" do
        let!(:protocol) { create(:calendar_protocol, calendars: [calendar], fixed_start_time: "09:00", fixed_end_time: "11:00") }

        context "with provided starts_at and ends_at" do
          let(:event_form) { build_event_form(action: :new, calendar: calendar, starts_at: "2016-04-07 14:30", ends_at: "2016-04-07 16:45") }

          it "should override the hour and minute with fixed times" do
            expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-07T09:00:00")
            expect(event_form.ends_at.to_fs(:default)).to eq("2016-04-07T11:00:00")
          end
        end

        context "without provided starts_at and ends_at" do
          let(:event_form) { build_event_form(action: :new, calendar: calendar, starts_at: nil, ends_at: nil) }

          around do |example|
            Timecop.freeze(Time.zone.parse("2016-04-01 10:00")) do
              example.run
            end
          end

          it "should apply fixed times to default dates" do
            expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-08T09:00:00")
            expect(event_form.ends_at.to_fs(:default)).to eq("2016-04-08T11:00:00")
          end
        end
      end

      context "when starts_at >= ends_at after fixed times are applied" do
        let!(:protocol) { create(:calendar_protocol, calendars: [calendar], fixed_start_time: "18:00", fixed_end_time: "06:00") }
        let(:event_form) { build_event_form(action: :new, calendar: calendar, starts_at: "2016-04-07 14:30", ends_at: "2016-04-07 16:45") }

        it "should add 1 day to ends_at" do
          expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-07T18:00:00")
          expect(event_form.ends_at.to_fs(:default)).to eq("2016-04-08T06:00:00")
        end
      end

      context "when only fixed_start_time is set" do
        let!(:protocol) { create(:calendar_protocol, calendars: [calendar], fixed_start_time: "10:00") }
        let(:event_form) { build_event_form(action: :new, calendar: calendar, starts_at: "2016-04-07 14:30", ends_at: "2016-04-07 16:45") }

        it "should only override starts_at hour/minute" do
          expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-07T10:00:00")
          expect(event_form.ends_at.to_fs(:default)).to eq("2016-04-07T16:45:00")
        end
      end

      context "when only fixed_end_time is set" do
        let!(:protocol) { create(:calendar_protocol, calendars: [calendar], fixed_end_time: "20:00") }
        let(:event_form) { build_event_form(action: :new, calendar: calendar, starts_at: "2016-04-07 14:30", ends_at: "2016-04-07 16:45") }

        it "should only override ends_at hour/minute" do
          expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-07T14:30:00")
          expect(event_form.ends_at.to_fs(:default)).to eq("2016-04-07T20:00:00")
        end
      end
    end

    context "other actions" do
      context "when starts_at and ends_at are not provided" do
        let(:event_form) { build_event_form(action: :edit, calendar: calendar, starts_at: nil, ends_at: nil) }

        it "should not set default values" do
          expect(event_form.starts_at).to be_nil
          expect(event_form.ends_at).to be_nil
        end
      end
    end
  end

  describe "normalization" do
    describe "all day events" do
      context "with all_day false" do
        let(:event_form) { build_event_form(calendar: calendar, all_day: false, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00") }

        it do
          event_form.validate
          expect(event_form.all_day).to be(false)
          expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-07T12:00:00")
          expect(event_form.ends_at.to_fs(:default)).to eq("2016-04-07T13:00:00")
        end
      end

      context "with all_day true" do
        before do
          allow(event_form).to receive(:rule_set).and_return(double(timed_events_only?: timed_only, errors: []))
        end

        context "with calendar permitting all day events" do
          let(:timed_only) { false }
          let(:event_form) { build_event_form(calendar: calendar, all_day: true, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00") }

          it do
            event_form.valid?
            expect(event_form.all_day).to be(true)
            expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-07T00:00:00")
            expect(event_form.ends_at.to_fs(:default)).to eq("2016-04-07T23:59:59")
          end
        end

        context "with calendar not permitting all day events" do
          let(:timed_only) { true }
          let(:event_form) { build_event_form(calendar: calendar, all_day: true, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00") }

          it do
            event_form.valid?
            expect(event_form.all_day).to be(false)
            expect(event_form.starts_at.to_fs(:default)).to eq("2016-04-07T12:00:00")
            expect(event_form.ends_at.to_fs(:default)).to eq("2016-04-07T13:00:00")
          end
        end
      end
    end
  end

  describe "validation" do
    describe "guidelines_accepted" do
      let(:guidelines_text) { "Please follow these rules" }
      let(:calendar_with_guidelines) { create(:calendar, guidelines: guidelines_text) }

      context "when creating a new event" do
        let(:event_form) { build_event_form(calendar: calendar_with_guidelines, guidelines_ok: guidelines_ok) }

        context "with guidelines_ok = '1'" do
          let(:guidelines_ok) { "1" }

          it "should be valid" do
            expect(event_form).to be_valid
          end
        end

        context "with guidelines_ok = '0'" do
          let(:guidelines_ok) { "0" }

          it "should have error" do
            expect(event_form).to have_errors(guidelines: "You must agree to the guidelines")
          end
        end

        context "with guidelines_ok = nil" do
          let(:guidelines_ok) { nil }

          it "should have error" do
            expect(event_form).to have_errors(guidelines: "You must agree to the guidelines")
          end
        end
      end

      context "when calendar has no guidelines" do
        let(:event_form) { build_event_form(calendar: calendar, guidelines_ok: nil) }

        it "should be valid without guidelines acceptance" do
          expect(event_form).to be_valid
        end
      end
    end

    describe "start_before_end" do
      let(:event_form) { build_event_form(calendar: calendar, starts_at: starts_at, ends_at: ends_at) }

      context "when starts_at is before ends_at" do
        let(:starts_at) { "2016-04-07 12:00" }
        let(:ends_at) { "2016-04-07 13:00" }

        it "should be valid" do
          expect(event_form).to be_valid
        end
      end

      context "when starts_at equals ends_at" do
        let(:starts_at) { "2016-04-07 12:00" }
        let(:ends_at) { "2016-04-07 12:00" }

        it "should have error" do
          expect(event_form).to have_errors(ends_at: "must be after start time")
        end
      end

      context "when starts_at is after ends_at" do
        let(:starts_at) { "2016-04-07 14:00" }
        let(:ends_at) { "2016-04-07 12:00" }

        it "should have error" do
          expect(event_form).to have_errors(ends_at: "must be after start time")
        end
      end

      context "when starts_at is blank" do
        let(:starts_at) { nil }
        let(:ends_at) { "2016-04-07 12:00" }

        it "should not trigger start_before_end validation" do
          event_form.valid?
          expect(event_form.errors[:ends_at]).not_to include("must be after start time")
        end
      end

      context "when ends_at is blank" do
        let(:starts_at) { "2016-04-07 12:00" }
        let(:ends_at) { nil }

        it "should not trigger start_before_end validation" do
          event_form.valid?
          expect(event_form.errors[:ends_at]).not_to include("must be after start time")
        end
      end
    end

    describe "no_overlap" do
      let!(:existing_event) do
        create(:event, calendar: calendar, starts_at: "2016-04-07 13:00", ends_at: "2016-04-07 15:00")
      end
      let(:event_form) { build_event_form(calendar: calendar) }

      context "with no overlap allowed" do
        let(:allow_overlap) { false }

        it "should not set error if no overlap on left" do
          event_form = build_event_form(calendar: calendar, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00")
          expect(event_form).to be_valid
        end

        it "should not set error if no overlap on right" do
          event_form = build_event_form(calendar: calendar, starts_at: "2016-04-07 15:00", ends_at: "2016-04-07 15:30")
          expect(event_form).to be_valid
        end

        it "should set error if partial overlap on left" do
          event_form = build_event_form(calendar: calendar, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:01")
          expect(event_form).to have_errors(base: "This event overlaps an existing one")
        end

        it "should set error if partial overlap on right" do
          event_form = build_event_form(calendar: calendar, starts_at: "2016-04-07 14:59", ends_at: "2016-04-07 15:30")
          expect(event_form).to have_errors(base: "This event overlaps an existing one")
        end

        it "should set error if full overlap" do
          event_form = build_event_form(calendar: calendar, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 15:30")
          expect(event_form).to have_errors(base: "This event overlaps an existing one")
        end

        it "should set error if interior overlap" do
          event_form = build_event_form(calendar: calendar, starts_at: "2016-04-07 14:30", ends_at: "2016-04-07 14:45")
          expect(event_form).to have_errors(base: "This event overlaps an existing one")
        end
      end

      context "with overlap allowed" do
        let(:allow_overlap) { true }

        it "should not set error if overlap" do
          event_form = build_event_form(calendar: calendar, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:01")
          expect(event_form).to be_valid
        end
      end
    end
  end

  describe "apply_rules" do
    context "with no protocols" do
      let(:event) { Calendars::Event.new(calendar: calendar) }

      it "should not set error" do
        event_form = build_event_form(calendar: calendar)
        expect(event_form).to be_valid
      end
    end

    context "with a protocol" do
      let!(:protocol) { create(:calendar_protocol, calendars: [calendar2], requires_kind: true) }

      it "should set an error if applicable" do
        event_form = build_event_form(calendar: calendar2)
        expect(event_form).to have_errors(kind: "can't be blank")
      end
    end

    context "with missing starts_at" do
      let!(:protocol) { create(:calendar_protocol, calendars: [calendar2], max_lead_days: 30) }

      it "should not apply rules since doing so would cause problems" do
        event_form = build_event_form(calendar: calendar2, starts_at: nil)
        expect(event_form).to have_errors(starts_at: "can't be blank")
        expect(event_form.errors.size).to eq(1)
      end
    end
  end

  describe "other validations" do
    describe "can't change start time on not-just-created event after it begins" do
      let(:ends_at) { starts_at + 1.hour }
      let(:event) do
        create(:event, created_at: created_at, starts_at: starts_at, ends_at: ends_at)
      end
      subject(:changed_event_form) do
        build_event_form(calendar: calendar, id: event.id, starts_at: (starts_at + 10.minutes).to_fs(:default), ends_at: (ends_at + 10.minutes).to_fs(:default))
      end

      context "just-created event with start time in past" do
        let(:created_at) { 5.minutes.ago }
        let(:starts_at) { 1.hour.ago }
        it { is_expected.to be_valid }
      end

      context "not-just-created event" do
        let(:created_at) { 2.hours.ago }

        context "original start time in future" do
          let(:starts_at) { 1.hour.from_now }
          it { is_expected.to be_valid }
        end

        context "original start time in past" do
          let(:starts_at) { 5.minutes.ago }

          context "admin user" do
            let(:current_user) { create(:admin) }
            it { is_expected.to be_valid }
          end

          context "normal changer" do
            it { is_expected.to have_errors(starts_at: "can't be changed after event begins") }
          end
        end
      end
    end

    describe "can't change end time to a time in the past on not-just-created event" do
      let(:starts_at) { Time.current + 30.minutes }
      let(:ends_at) { starts_at + 1.hour }
      let(:event) { create(:event, created_at: created_at, starts_at: starts_at, ends_at: ends_at) }
      subject(:changed_event_form) do
        build_event_form(calendar: calendar, id: event.id, starts_at: new_starts_at.to_fs(:default), ends_at: new_ends_at.to_fs(:default))
      end

      context "just-created event" do
        let(:created_at) { 5.minutes.ago }
        let(:new_starts_at) { Time.current - 2.minutes }
        let(:new_ends_at) { Time.current - 1.minute }
        it { is_expected.to be_valid }
      end

      context "not-just-created event" do
        let(:created_at) { 2.hours.ago }

        context "new end time in future" do
          let(:new_starts_at) { Time.current - 2.minutes }
          let(:new_ends_at) { Time.current + 1.minute }
          it { is_expected.to be_valid }
        end

        context "new end time in past" do
          let(:new_starts_at) { Time.current - 2.minutes }
          let(:new_ends_at) { Time.current - 1.minute }
          it { is_expected.to have_errors(ends_at: "can't be changed to a time in the past") }
        end
      end
    end
  end
end
