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

  let(:user) { admin }

  def submit(params)
    described_class.new(eventlet: eventlet, current_user: user, params: params)
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

    it "allows a move well beyond the eventlet offset cap (no per-calendar offset involved)" do
      two_days = 2.days
      form = submit(calendar_scope: "all", series_scope: "series",
        starts_at: (base_start + two_days).iso8601, ends_at: (base_end + two_days).iso8601)

      expect(form.save).to be(true)
      expect(event.reload.starts_at).to eq(base_start + two_days)
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

    it "rejects a drag beyond the max offset with a plain-language message" do
      too_far = Calendars::Eventlet::MAX_OFFSET_SECONDS + 1.hour
      form = submit(calendar_scope: "this", series_scope: "series",
        starts_at: (base_start + too_far).iso8601, ends_at: (base_end + too_far).iso8601)

      expect(form.save).to be(false)
      # The friendly form-level message, not the raw "start offset is not included" model error.
      expect(form.errors[:base].join).to match(/can't be more than 12 hours apart/i)
      expect(form.errors[:start_offset]).to be_empty
    end
  end

  describe "an all-day event" do
    let(:eventlet) do
      create(:eventlet, calendar: calendar, all_day: true,
        starts_at: base_start.midnight, ends_at: base_start.midnight)
    end

    it "keeps it all-day on the dropped day, converting FullCalendar's exclusive end" do
      target = (base_start + 2.days).to_date
      # FullCalendar posts the exclusive day-after as the all-day end; we store an inclusive end.
      form = submit(calendar_scope: "all", series_scope: "series",
        starts_at: target.to_s, ends_at: (target + 1).to_s)

      expect(form.save).to be(true)
      expect(event.reload).to be_all_day
      expect(event.starts_at).to eq(target.in_time_zone.midnight)
      expect(event.ends_at).to eq(target.in_time_zone.midnight + 1.day - 1.second)
    end
  end

  context "with a recurring event" do
    subject(:form) { submit(params) }

    # A second calendar, plus overrides on other occurrences covering each kind (moved on all
    # calendars, deleted, shifted on one calendar), so "leaves the series untouched" has something to
    # notice if a drag disturbs them.
    let!(:other_eventlet) { Calendars::Eventlet.create!(event_id: event.id, calendar: calendar2) }
    let(:occurrence) { base_start + 1.week }

    # The occurrence whose own override a drag is allowed to write. Everything else about the series
    # must be left alone. Nil for a refused drag, which must change nothing at all.
    let(:dragged_occurrence) { occurrence }

    before do
      event.update!(recurrence_rule: IceCube::Rule.weekly.to_hash)
      create(:event_override, event: event, occurrence_start: base_start + 2.weeks,
        starts_at: base_start + 2.weeks + 1.hour, ends_at: base_end + 2.weeks + 1.hour)
      create(:event_override, event: event, occurrence_start: base_start + 3.weeks, deleted: true)
      anchor = create(:event_override, event: event, occurrence_start: base_start + 4.weeks)
      create(:eventlet_override, event_override: anchor, eventlet: eventlet,
        start_offset: 15.minutes.to_i, end_offset: 15.minutes.to_i)
    end

    shared_examples_for "a drag that leaves the series untouched" do
      it "leaves the series untouched" do
        before = series_snapshot(excluding: dragged_occurrence)
        form.save
        expect(series_snapshot(excluding: dragged_occurrence)).to eq(before)
      end
    end

    # Everything about the series a drag could change: the event's own times and rule, every
    # eventlet's offsets, and every override except the dragged occurrence's.
    def series_snapshot(excluding:)
      event.reload
      overrides = Calendars::EventOverride.where(event_id: event.id).includes(:eventlet_overrides)
        .order(:occurrence_start).reject { |o| excluding && o.occurrence_start == excluding }
      {
        event: event.attributes.slice("starts_at", "ends_at", "recurrence_rule", "recurrence_end_date"),
        eventlets: Calendars::Eventlet.where(event_id: event.id).order(:id)
          .map { |e| [e.id, e.start_offset, e.end_offset] },
        overrides: overrides.map do |o|
          eventlet_overrides = o.eventlet_overrides.sort_by(&:id)
            .map { |eo| [eo.eventlet_id, eo.deleted, eo.start_offset, eo.end_offset] }
          [o.occurrence_start, o.deleted, o.starts_at, o.ends_at, eventlet_overrides]
        end
      }
    end

    def override_for(occurrence_start)
      Calendars::EventOverride.find_by(event_id: event.id, occurrence_start: occurrence_start)
    end

    describe "all calendars + this occurrence" do
      let(:params) do
        {calendar_scope: "all", series_scope: "occurrence", occurrence_start: occurrence.to_i,
         starts_at: (occurrence + 2.hours).iso8601, ends_at: (occurrence + 3.hours).iso8601}
      end

      it "creates an EventOverride at the dropped time" do
        expect(form.save).to be(true)
        override = override_for(occurrence)
        expect(override.starts_at).to eq(occurrence + 2.hours)
        expect(override.ends_at).to eq(occurrence + 3.hours)
      end

      it_behaves_like "a drag that leaves the series untouched"

      context "when the occurrence was already moved on all calendars" do
        before do
          create(:event_override, event: event, occurrence_start: occurrence,
            starts_at: occurrence + 1.hour, ends_at: occurrence + 2.hours)
        end

        it "moves the existing override to the dropped time rather than adding a second one" do
          expect(form.save).to be(true)
          expect(Calendars::EventOverride.where(event_id: event.id, occurrence_start: occurrence).count)
            .to eq(1)
          expect(override_for(occurrence).starts_at).to eq(occurrence + 2.hours)
          expect(override_for(occurrence).ends_at).to eq(occurrence + 3.hours)
        end

        it_behaves_like "a drag that leaves the series untouched"
      end

      context "when the occurrence was already shifted on this calendar" do
        # The setup shifts the fifth occurrence +15 minutes on this calendar.
        let(:occurrence) { base_start + 4.weeks }

        it "shows it at the dropped time, net of that shift" do
          expect(form.save).to be(true)

          expect(override_for(occurrence).starts_at).to eq(occurrence + 105.minutes)
          shown = Calendars::OccurrenceResolver.new(eventlet, occurrence.to_i).resolve
          expect(shown.starts_at).to eq(occurrence + 2.hours)
          expect(shown.ends_at).to eq(occurrence + 3.hours)
        end

        it_behaves_like "a drag that leaves the series untouched"
      end
    end

    describe "this calendar + this occurrence" do
      let(:params) do
        {calendar_scope: "this", series_scope: "occurrence", occurrence_start: occurrence.to_i,
         starts_at: (occurrence + 30.minutes).iso8601, ends_at: (occurrence + 90.minutes).iso8601}
      end

      it "creates an anchor EventOverride plus an EventletOverride with offsets" do
        expect(form.save).to be(true)

        anchor = override_for(occurrence)
        # The anchor exists only to hold occurrence identity; it carries no time change of its own.
        expect(anchor.starts_at).to be_nil

        override = anchor.eventlet_overrides.sole
        expect(override.eventlet_id).to eq(eventlet.id)
        expect(override.start_offset).to eq(30.minutes.to_i)
        expect(override.end_offset).to eq(30.minutes.to_i)
      end

      it_behaves_like "a drag that leaves the series untouched"

      context "when the occurrence was already moved on all calendars" do
        let!(:existing) do
          create(:event_override, event: event, occurrence_start: occurrence,
            starts_at: occurrence + 1.hour, ends_at: occurrence + 2.hours)
        end

        let(:params) do
          {calendar_scope: "this", series_scope: "occurrence", occurrence_start: occurrence.to_i,
           starts_at: (occurrence + 90.minutes).iso8601, ends_at: (occurrence + 150.minutes).iso8601}
        end

        it "reuses the existing EventOverride, measuring offsets from its moved time" do
          expect(form.save).to be(true)
          expect(Calendars::EventOverride.where(event_id: event.id, occurrence_start: occurrence).count)
            .to eq(1)
          expect(existing.eventlet_overrides.sole.start_offset).to eq(30.minutes.to_i)
        end

        it_behaves_like "a drag that leaves the series untouched"
      end
    end

    describe "all calendars + all occurrences" do
      # Dragging the second occurrence an hour later.
      let(:params) do
        {calendar_scope: "all", series_scope: "series", occurrence_start: occurrence.to_i,
         starts_at: (occurrence + 1.hour).iso8601, ends_at: (occurrence + 2.hours).iso8601}
      end

      def occurrence_times
        window = (base_start - 1.day)..(base_start + 5.weeks + 12.hours)
        event.reload.occurrences_between(window).map { |s, e| [s.to_time, e] }
      end

      it "shifts every occurrence by the drag distance rather than re-anchoring on the dragged one" do
        before = occurrence_times
        expect(form.save).to be(true)
        expect(occurrence_times).to eq(before.map { |s, e| [s + 1.hour, e + 1.hour] })
      end

      it "re-keys the other overrides, keeping an already-moved occurrence at its own time" do
        expect(form.save).to be(true)

        moved = override_for(base_start + 2.weeks + 1.hour)
        expect(moved.starts_at).to eq(base_start + 2.weeks + 1.hour)
        expect(override_for(base_start + 3.weeks + 1.hour)).to be_deleted
        expect(override_for(base_start + 4.weeks + 1.hour).eventlet_overrides.sole.start_offset)
          .to eq(15.minutes.to_i)
      end

      context "when resizing" do
        let(:params) do
          {calendar_scope: "all", series_scope: "series", occurrence_start: occurrence.to_i,
           starts_at: occurrence.iso8601, ends_at: (occurrence + 90.minutes).iso8601}
        end

        it "changes the series' duration but not its start" do
          expect(form.save).to be(true)
          expect(event.reload.starts_at).to eq(base_start)
          expect(event.ends_at).to eq(base_start + 90.minutes)
        end
      end

      context "when the dragged occurrence was already moved on all calendars" do
        before do
          create(:event_override, event: event, occurrence_start: occurrence,
            starts_at: occurrence + 1.hour, ends_at: occurrence + 2.hours)
        end

        # Shown at +1h, dropped at +3h: two hours later.
        let(:params) do
          {calendar_scope: "all", series_scope: "series", occurrence_start: occurrence.to_i,
           starts_at: (occurrence + 3.hours).iso8601, ends_at: (occurrence + 4.hours).iso8601}
        end

        it "lands it at the drop, leaving other moved occurrences where they were" do
          expect(form.save).to be(true)

          expect(event.reload.starts_at).to eq(base_start + 2.hours)
          dragged = override_for(occurrence + 2.hours)
          expect(dragged.starts_at).to eq(occurrence + 3.hours)
          expect(dragged.ends_at).to eq(occurrence + 4.hours)
          expect(override_for(base_start + 2.weeks + 2.hours).starts_at).to eq(base_start + 2.weeks + 1.hour)
        end
      end

      context "with a rule pinned to the series' weekday" do
        before do
          weekday = base_start.strftime("%A").downcase.to_sym
          event.update!(recurrence_rule: IceCube::Rule.weekly.day(weekday).to_hash)
        end

        it "allows a move within the same day" do
          expect(form.save).to be(true)
          expect(event.reload.starts_at).to eq(base_start + 1.hour)
        end

        context "when moving to another day" do
          let(:dragged_occurrence) { nil }
          let(:params) do
            {calendar_scope: "all", series_scope: "series", occurrence_start: occurrence.to_i,
             starts_at: (occurrence + 1.day).iso8601, ends_at: (occurrence + 1.day + 1.hour).iso8601}
          end

          it "is refused" do
            expect(form.save).to be(false)
            expect(form.errors[:base].join).to match(/fixed pattern/)
          end

          it_behaves_like "a drag that leaves the series untouched"
        end
      end
    end

    describe "this calendar + all occurrences" do
      # Dragging the second occurrence, 30 minutes later at the start and 45 at the end.
      let(:params) do
        {calendar_scope: "this", series_scope: "series", occurrence_start: occurrence.to_i,
         starts_at: (occurrence + 30.minutes).iso8601, ends_at: (occurrence + 105.minutes).iso8601}
      end

      # Changes this eventlet's offsets, so only the event and the overrides must stay put.
      it "shifts only this eventlet's offsets, leaving the event, other calendars, and overrides alone" do
        before = series_snapshot(excluding: nil).except(:eventlets)

        expect(form.save).to be(true)
        expect(eventlet.reload.start_offset).to eq(30.minutes.to_i)
        expect(eventlet.end_offset).to eq(45.minutes.to_i)
        expect(other_eventlet.reload.start_offset).to eq(0)
        expect(series_snapshot(excluding: nil).except(:eventlets)).to eq(before)
      end

      context "when the dragged occurrence was already shifted on this calendar" do
        # The setup shifts the fifth occurrence +15 minutes here. Shown at +15m, dropped at +45m.
        let(:occurrence) { base_start + 4.weeks }
        let(:params) do
          {calendar_scope: "this", series_scope: "series", occurrence_start: occurrence.to_i,
           starts_at: (occurrence + 45.minutes).iso8601, ends_at: (occurrence + 105.minutes).iso8601}
        end

        it "lands it at the drop and moves the rest of the series by the same distance" do
          expect(form.save).to be(true)

          expect(eventlet.reload.start_offset).to eq(30.minutes.to_i)
          shown = Calendars::OccurrenceResolver.new(eventlet, occurrence.to_i).resolve
          expect(shown.starts_at).to eq(occurrence + 45.minutes)
          expect(shown.ends_at).to eq(occurrence + 105.minutes)
        end
      end
    end

    context "with a series that has started" do
      # Frozen after setup rather than around it, so the series wasn't "recently created".
      before { Timecop.freeze(base_start + 1.day) }
      after { Timecop.return }

      context "as the creator" do
        let(:user) { event.creator }
        let(:params) do
          {calendar_scope: "all", series_scope: "occurrence", occurrence_start: occurrence.to_i,
           starts_at: (occurrence + 1.hour).iso8601, ends_at: (occurrence + 2.hours).iso8601}
        end

        it "allows moving a future occurrence" do
          expect(form.save).to be(true)
        end

        context "with a past occurrence" do
          let(:dragged_occurrence) { nil }
          let(:occurrence) { base_start }

          it "refuses the move" do
            expect(form.save).to be(false)
            expect(form.errors[:starts_at]).to include("can't be changed after event begins")
          end

          it_behaves_like "a drag that leaves the series untouched"
        end

        context "with an occurrence in progress" do
          let(:dragged_occurrence) { nil }

          before { Timecop.freeze(occurrence + 30.minutes) }

          it "refuses the move" do
            expect(form.save).to be(false)
            expect(form.errors[:starts_at]).to include("can't be changed after event begins")
          end
        end
      end

      context "as an admin, moving a past occurrence" do
        let(:occurrence) { base_start }
        let(:params) do
          {calendar_scope: "all", series_scope: "occurrence", occurrence_start: occurrence.to_i,
           starts_at: (base_start + 2.days).iso8601, ends_at: (base_start + 2.days + 1.hour).iso8601}
        end

        it "allows it" do
          expect(form.save).to be(true)
        end
      end

      %w[all this].each do |calendar_scope|
        context "moving all occurrences (#{calendar_scope} calendars)" do
          let(:dragged_occurrence) { nil }
          let(:params) do
            {calendar_scope: calendar_scope, series_scope: "series", occurrence_start: occurrence.to_i,
             starts_at: (occurrence + 1.hour).iso8601, ends_at: (occurrence + 2.hours).iso8601}
          end

          it "refuses even an admin, since past occurrences would move" do
            expect(form.save).to be(false)
            expect(form.errors[:base].join).to match(/already started.*“This only”/)
          end

          it_behaves_like "a drag that leaves the series untouched"

          context "when the series was created moments ago" do
            before { event.update_columns(created_at: 10.minutes.ago) }

            it "allows it" do
              expect(form.save).to be(true)
            end
          end
        end
      end
    end

    context "when the dragged occurrence was deleted in the meantime" do
      let(:dragged_occurrence) { nil }
      let(:occurrence) { base_start + 3.weeks }
      let(:params) do
        {calendar_scope: "all", series_scope: "series", occurrence_start: occurrence.to_i,
         starts_at: (occurrence + 1.hour).iso8601, ends_at: (occurrence + 2.hours).iso8601}
      end

      it "is refused" do
        expect(form.save).to be(false)
        expect(form.errors[:base].join).to match(/no longer exists/)
      end

      it_behaves_like "a drag that leaves the series untouched"
    end

    context "with an occurrence that isn't in the series" do
      let(:dragged_occurrence) { nil }
      let(:params) do
        bogus = occurrence + 1.day
        {calendar_scope: "this", series_scope: "occurrence", occurrence_start: bogus.to_i,
         starts_at: bogus.iso8601, ends_at: (bogus + 1.hour).iso8601}
      end

      it "is rejected" do
        expect(form.save).to be(false)
        expect(form.errors[:occurrence_start]).to be_present
      end

      it_behaves_like "a drag that leaves the series untouched"
    end

    context "with no occurrence_start for a single-occurrence change" do
      let(:dragged_occurrence) { nil }
      let(:params) do
        {calendar_scope: "this", series_scope: "occurrence",
         starts_at: base_start.iso8601, ends_at: base_end.iso8601}
      end

      it "is rejected" do
        expect(form.save).to be(false)
        expect(form.errors[:occurrence_start]).to be_present
      end

      it_behaves_like "a drag that leaves the series untouched"
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
