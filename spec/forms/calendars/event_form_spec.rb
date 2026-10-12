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

  # See EventForm's class comment for how a repeating event is created and edited.
  describe "repeating events" do
    let(:allow_overlap) { true }
    # Mondays at 6pm, starting next week, so nothing is in the past.
    let(:start) { Time.zone.now.next_week.midnight + 18.hours }
    let(:repeat_defaults) do
      {repeat_frequency: "weekly", repeat_interval: "1", repeat_monthly_by: "day_of_month",
       repeat_ends: "never"}
    end

    def wk(n)
      start + n.weeks
    end

    def create_form(starts_at: start, ends_at: start + 1.hour, all_day: false, on: calendar, **repeat)
      described_class.new(action: :create, current_user: current_user,
        params: {calendar_id: on.id, name: "Book club", guidelines_ok: "1", all_day: all_day,
                 starts_at: starts_at.iso8601, ends_at: ends_at.iso8601, **repeat_defaults, **repeat})
    end

    def first_starts(event, count = 4)
      event.reload.schedule.first(count).map(&:to_time)
    end

    describe "creating" do
      it "saves a weekly series starting on the start date" do
        form = create_form
        expect(form.save).to be(true)
        expect(first_starts(form.event)).to eq([wk(0), wk(1), wk(2), wk(3)])
      end

      it "saves a daily series every N days" do
        form = create_form(repeat_frequency: "daily", repeat_interval: "3")
        expect(form.save).to be(true)
        expect(first_starts(form.event, 3)).to eq([start, start + 3.days, start + 6.days])
      end

      it "saves a monthly series on the start's nth weekday" do
        form = create_form(repeat_frequency: "monthly", repeat_monthly_by: "day_of_week")
        expect(form.save).to be(true)
        nth = ((start.day - 1) / 7) + 1
        expect(first_starts(form.event, 3).map { |t| [t.wday, [((t.day - 1) / 7) + 1, nth].min] })
          .to all(eq([start.wday, [nth, 4].min]))
      end

      it "saves a yearly series" do
        form = create_form(repeat_frequency: "yearly")
        expect(form.save).to be(true)
        expect(first_starts(form.event, 2)).to eq([start, start + 1.year])
      end

      it "ends on a date" do
        form = create_form(repeat_ends: "on_date", repeat_ends_on: I18n.l(wk(2).to_date, format: "%b %d %Y"))
        expect(form.save).to be(true)
        expect(first_starts(form.event, 10)).to eq([wk(0), wk(1), wk(2)])
        expect(form.event.recurrence_end_date).to eq(wk(2).to_date)
      end

      it "ends after a number of times" do
        form = create_form(repeat_ends: "after_count", repeat_count: "5")
        expect(form.save).to be(true)
        expect(first_starts(form.event, 10).size).to eq(5)
      end

      it "saves an all-day series" do
        day = start.to_date
        form = create_form(all_day: true, starts_at: day.in_time_zone, ends_at: day.in_time_zone,
          repeat_ends: "on_date", repeat_ends_on: (day + 14).to_s)
        expect(form.save).to be(true)
        expect(first_starts(form.event, 10).map(&:to_date)).to eq([day, day + 7, day + 14])
      end

      it "keeps the local time across a DST change" do
        Time.use_zone("America/Toronto") do
          dst_start = Time.zone.parse("2030-10-28 19:00")
          form = create_form(starts_at: dst_start, ends_at: dst_start + 1.hour)
          expect(form.save).to be(true)
          expect(first_starts(form.event, 2).last.strftime("%H:%M %Z")).to eq("19:00 EST")
        end
      end

      it "doesn't repeat when Repeats is Never" do
        form = create_form(repeat_frequency: "none")
        expect(form.save).to be(true)
        expect(form.event.reload).not_to be_recurring
      end

      it "makes an existing one-off event repeat" do
        event = create(:event, calendar: calendar, creator: current_user, starts_at: start,
          ends_at: start + 1.hour)
        form = described_class.new(action: :update, current_user: current_user, id: event.id,
          params: {guidelines_ok: "1", **repeat_defaults})
        expect(form.save).to be(true)
        expect(first_starts(event, 2)).to eq([wk(0), wk(1)])
      end

      describe "refusals" do
        it "refuses an end date before the start" do
          form = create_form(repeat_ends: "on_date", repeat_ends_on: (start.to_date - 1).to_s)
          expect(form.save).to be(false)
          expect(form.errors[:repeat_ends_on]).to include("must be on or after the start date")
        end

        it "refuses an event longer than the time between repeats" do
          form = create_form(repeat_frequency: "daily", ends_at: start + 25.hours)
          expect(form.save).to be(false)
          expect(form.errors[:base].join).to match(/longer than the time between repeats/)
        end

        it "refuses a count below two and an interval below one" do
          expect(create_form(repeat_ends: "after_count", repeat_count: "1").tap(&:save).errors[:repeat_count])
            .to be_present
          expect(create_form(repeat_interval: "0").tap(&:save).errors[:repeat_interval]).to be_present
        end

        context "on a calendar that doesn't allow repeating events" do
          let(:allow_overlap) { false }

          it "says so, and why" do
            form = create_form
            expect(form.recurrence_offered?).to be(false)
            expect(form.recurrence_blockers).to eq([:overlap_not_allowed])
            expect(form.save).to be(false)
            expect(form.errors[:repeat_frequency]).to include("isn't available on this calendar")
          end
        end
      end

      it "ignores repeat settings on a meal event" do
        meal = create(:meal, calendars: [calendar])
        event = create(:event, creator: nil, calendar: calendar, meal: meal, kind: "_meal",
          starts_at: meal.served_at - 1.hour, ends_at: meal.served_at + 1.hour)
        form = described_class.new(action: :update, current_user: create(:admin), id: event.id,
          params: {guidelines_ok: "1", **repeat_defaults})
        expect(form.recurrence_offered?).to be(false)
        form.save
        expect(event.reload).not_to be_recurring
      end
    end

    describe "editing a series" do
      let!(:event) do
        create(:event, calendar: calendar, creator: current_user, name: "Book club", starts_at: start,
          ends_at: start + 1.hour,
          recurrence_rule: IceCube::Rule.weekly.day(start.wday).to_hash).tap do |e|
          e.update_columns(created_at: 1.week.ago)
          e.eventlets.update_all(created_at: 1.week.ago)
        end
      end

      def edit_form(occurrence:, scope: nil, user: current_user, **params)
        described_class.new(action: :update, current_user: user, id: event.id,
          params: {guidelines_ok: "1", occurrence_start: occurrence.to_i, series_scope: scope, **params})
      end

      def split_off
        Calendars::Event.where.not(id: event.id).sole
      end

      it "shows the opened occurrence's times" do
        form = edit_form(occurrence: wk(2))
        expect([form.starts_at, form.ends_at]).to eq([wk(2), wk(2) + 1.hour])
      end

      it "offers both choices before the series starts, defaulting to all occurrences" do
        form = edit_form(occurrence: wk(2))
        expect(form.series_scope_options).to eq(%w[following series])
        expect(form.series_scope).to eq("series")
      end

      it "doesn't offer this and following from the first occurrence" do
        expect(edit_form(occurrence: wk(0)).series_scope_options).to eq(%w[series])
      end

      describe "all occurrences" do
        it "moves every occurrence by the change to the opened one, without re-anchoring on it" do
          form = edit_form(occurrence: wk(2), scope: "series",
            starts_at: (wk(2) + 1.hour).iso8601, ends_at: (wk(2) + 2.hours).iso8601)
          expect(form.save).to be(true)
          expect(first_starts(event)).to eq([wk(0), wk(1), wk(2), wk(3)].map { |t| t + 1.hour })
        end

        it "changes other fields on every occurrence" do
          expect(edit_form(occurrence: wk(2), scope: "series", name: "Reading group").save).to be(true)
          expect(event.reload.name).to eq("Reading group")
          expect(Calendars::Event.count).to eq(1)
        end
      end

      describe "this and following" do
        it "gives the change to a new series from the opened occurrence, leaving earlier ones" do
          expect(edit_form(occurrence: wk(2), scope: "following", name: "Reading group").save).to be(true)

          expect(event.reload.name).to eq("Book club")
          expect(first_starts(event, 10)).to eq([wk(0), wk(1)])
          expect(split_off.name).to eq("Reading group")
          expect(first_starts(split_off, 2)).to eq([wk(2), wk(3)])
        end

        it "moves the new series by the change to the opened occurrence" do
          form = edit_form(occurrence: wk(2), scope: "following",
            starts_at: (wk(2) + 1.day + 1.hour).iso8601, ends_at: (wk(2) + 1.day + 2.hours).iso8601)
          expect(form.save).to be(true)
          expect(first_starts(event, 10)).to eq([wk(0), wk(1)])
          expect(first_starts(split_off, 2)).to eq([wk(2) + 1.day + 1.hour, wk(3) + 1.day + 1.hour])
        end
      end

      context "once the series has started" do
        before { Timecop.freeze(start + 1.day) }
        after { Timecop.return }

        it "offers only this and following, from a future occurrence" do
          expect(edit_form(occurrence: wk(2)).series_scope_options).to eq(%w[following])
        end

        it "refuses all occurrences, even for an admin" do
          form = edit_form(occurrence: wk(2), scope: "series", user: create(:admin), name: "Renamed")
          expect(form.save).to be(false)
          expect(form.errors[:base].join).to match(/already started/)
          expect(event.reload.name).to eq("Book club")
        end

        it "offers nothing from a past occurrence" do
          form = edit_form(occurrence: wk(0), name: "Renamed")
          expect(form.series_scope_options).to be_empty
          expect(form.save).to be(false)
          expect(form.errors[:base].join).to match(/can't be changed from this occurrence/)
        end
      end

      describe "changing the pattern" do
        def daily
          repeat_defaults.merge(repeat_frequency: "daily")
        end

        it "is allowed with no changed occurrences" do
          expect(edit_form(occurrence: wk(1), scope: "series", **daily).save).to be(true)
          expect(first_starts(event, 3)).to eq([start, start + 1.day, start + 2.days])
        end

        context "with a deleted occurrence" do
          before { create(:event_override, event: event, occurrence_start: wk(3), deleted: true) }

          it "is refused for the part with it" do
            form = edit_form(occurrence: wk(1), scope: "series", **daily)
            expect(form.save).to be(false)
            expect(form.errors[:base].join).to match(/1 occurrence in the part being changed/)
          end

          it "is allowed from after it" do
            expect(edit_form(occurrence: wk(4), scope: "following", **daily).save).to be(true)
            expect(first_starts(split_off, 2)).to eq([wk(4), wk(4) + 1.day])
          end
        end

        it "counts a move to another weekday" do
          create(:event_override, event: event, occurrence_start: wk(3), deleted: true)
          form = edit_form(occurrence: wk(1), scope: "series", **repeat_defaults,
            starts_at: (wk(1) + 1.day).iso8601, ends_at: (wk(1) + 1.day + 1.hour).iso8601)
          expect(form.save).to be(false)
          expect(form.errors[:base].join).to match(/days it repeats on/)
        end
      end

      describe "changing the end" do
        it "removes changes to occurrences past a new, earlier end" do
          kept = create(:event_override, event: event, occurrence_start: wk(1), deleted: true)
          dropped = create(:event_override, event: event, occurrence_start: wk(5), deleted: true)
          form = edit_form(occurrence: wk(0), scope: "series", **repeat_defaults,
            repeat_ends: "on_date", repeat_ends_on: wk(3).to_date.to_s)

          expect(form.save).to be(true)
          expect(first_starts(event, 10).last).to eq(wk(3))
          expect(Calendars::EventOverride.where(id: kept.id)).to exist
          expect(Calendars::EventOverride.where(id: dropped.id)).not_to exist
        end

        it "can end after a number of times" do
          form = edit_form(occurrence: wk(0), scope: "series", **repeat_defaults,
            repeat_ends: "after_count", repeat_count: "3")
          expect(form.save).to be(true)
          expect(first_starts(event, 10).size).to eq(3)
        end
      end

      describe "switching to all-day" do
        it "is refused with changed occurrences" do
          create(:event_override, event: event, occurrence_start: wk(3), deleted: true)
          form = edit_form(occurrence: wk(0), scope: "series", all_day: true)
          expect(form.save).to be(false)
          expect(form.errors[:base].join).to match(/switch between all-day and timed/)
        end

        it "clears each calendar's offsets" do
          event.eventlets.first.update!(start_offset: -30.minutes.to_i, end_offset: 30.minutes.to_i)
          expect(edit_form(occurrence: wk(0), scope: "series", all_day: true).save).to be(true)
          expect(event.reload).to be_all_day
          expect(event.eventlets.map { |e| [e.start_offset, e.end_offset] }).to eq([[0, 0]])
        end

        it "makes only the new series all-day with this and following" do
          event.eventlets.first.update!(start_offset: -30.minutes.to_i, end_offset: 30.minutes.to_i)
          expect(edit_form(occurrence: wk(2), scope: "following", all_day: true).save).to be(true)
          expect(event.reload).not_to be_all_day
          expect(split_off).to be_all_day
          expect(split_off.eventlets.map { |e| [e.start_offset, e.end_offset] }).to eq([[0, 0]])
        end
      end

      it "refuses changing Repeats to Never" do
        form = edit_form(occurrence: wk(0), scope: "series", **repeat_defaults, repeat_frequency: "none")
        expect(form.save).to be(false)
        expect(form.errors[:repeat_frequency].join).to match(/delete this and the following/)
      end

      it "refuses editing from an occurrence deleted in the meantime" do
        create(:event_override, event: event, occurrence_start: wk(2), deleted: true)
        form = edit_form(occurrence: wk(2), scope: "following", name: "Renamed")
        expect(form.save).to be(false)
        expect(form.errors[:base].join).to match(/no longer exists/)
      end

      it "checks protocol rules against the new times" do
        create(:calendar_protocol, calendars: [calendar], max_length_minutes: 60)
        form = edit_form(occurrence: wk(2), scope: "series",
          starts_at: wk(2).iso8601, ends_at: (wk(2) + 2.hours).iso8601)
        expect(form.save).to be(false)
        expect(form.errors.full_messages.join).to match(/1 hour/)
      end

      context "with a pattern the form can't show" do
        before { event.update!(recurrence_rule: IceCube::Rule.weekly.day(:monday, :thursday).to_hash) }

        it "keeps the pattern while changing other things" do
          rule = event.reload.recurrence_rule
          form = edit_form(occurrence: event.starts_at, scope: "series", name: "Renamed")
          expect(form.pattern_editable?).to be(false)
          expect(form.save).to be(true)
          expect(event.reload.recurrence_rule).to eq(rule)
          expect(event.name).to eq("Renamed")
        end
      end
    end
  end
end
