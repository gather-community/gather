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

    describe "all calendars + this and following" do
      # Dragging the second occurrence an hour later.
      let(:params) do
        {calendar_scope: "all", series_scope: "following", occurrence_start: occurrence.to_i,
         starts_at: (occurrence + 1.hour).iso8601, ends_at: (occurrence + 2.hours).iso8601}
      end
      let(:horizon) { base_start + 5.weeks + 12.hours }

      def continuation
        Calendars::Event.where.not(id: event.id).sole
      end

      def starts_of(series)
        series.reload.schedule.occurrences(horizon).map(&:to_time)
      end

      it "moves this and later occurrences by the drag distance, leaving earlier ones in place" do
        before = starts_of(event)

        expect(form.save).to be(true)
        expect(starts_of(event)).to eq(before.select { |t| t < occurrence })
        expect(starts_of(continuation)).to eq(before.select { |t| t >= occurrence }.map { |t| t + 1.hour })
      end

      it "carries later overrides to the new series, keeping an already-moved occurrence at its own time" do
        expect(form.save).to be(true)

        moved = Calendars::EventOverride.find_by(event_id: continuation.id,
          occurrence_start: base_start + 2.weeks + 1.hour)
        expect(moved.starts_at).to eq(base_start + 2.weeks + 1.hour)
        expect(Calendars::EventOverride.find_by(event_id: continuation.id,
          occurrence_start: base_start + 3.weeks + 1.hour)).to be_deleted
        calendar_only = Calendars::EventOverride.find_by(event_id: continuation.id,
          occurrence_start: base_start + 4.weeks + 1.hour)
        expect(calendar_only.eventlet_overrides.sole.start_offset).to eq(15.minutes.to_i)
      end

      context "when resizing" do
        let(:params) do
          {calendar_scope: "all", series_scope: "following", occurrence_start: occurrence.to_i,
           starts_at: occurrence.iso8601, ends_at: (occurrence + 90.minutes).iso8601}
        end

        it "changes only the new series' duration" do
          expect(form.save).to be(true)
          expect(continuation.ends_at - continuation.starts_at).to eq(90.minutes)
          expect(event.reload.ends_at - event.starts_at).to eq(1.hour)
        end
      end

      context "when the dragged occurrence was already moved on all calendars" do
        before do
          create(:event_override, event: event, occurrence_start: occurrence,
            starts_at: occurrence + 1.hour, ends_at: occurrence + 2.hours)
        end

        # Shown at +1h, dropped at +3h: two hours later.
        let(:params) do
          {calendar_scope: "all", series_scope: "following", occurrence_start: occurrence.to_i,
           starts_at: (occurrence + 3.hours).iso8601, ends_at: (occurrence + 4.hours).iso8601}
        end

        it "lands it at the drop" do
          expect(form.save).to be(true)

          dragged = Calendars::EventOverride.find_by(event_id: continuation.id,
            occurrence_start: occurrence + 2.hours)
          expect(dragged.starts_at).to eq(occurrence + 3.hours)
          expect(dragged.ends_at).to eq(occurrence + 4.hours)
        end
      end

      context "from the first occurrence" do
        let(:occurrence) { base_start }

        it "moves the whole series instead of splitting it" do
          expect(form.save).to be(true)
          expect(event.reload.starts_at).to eq(base_start + 1.hour)
          expect(Calendars::Event.where.not(id: event.id)).to be_empty
        end
      end

      context "with a rule pinned to the series' weekday, moving to another day" do
        let(:dragged_occurrence) { nil }
        let(:params) do
          {calendar_scope: "all", series_scope: "following", occurrence_start: occurrence.to_i,
           starts_at: (occurrence + 1.day).iso8601, ends_at: (occurrence + 1.day + 1.hour).iso8601}
        end

        before do
          weekday = base_start.strftime("%A").downcase.to_sym
          event.update!(recurrence_rule: IceCube::Rule.weekly.day(weekday).to_hash)
        end

        it "is refused" do
          expect(form.save).to be(false)
          expect(form.errors[:base].join).to match(/fixed pattern/)
        end

        it_behaves_like "a drag that leaves the series untouched"
      end
    end

    describe "this calendar + this and following" do
      # Dragging the second occurrence 30 minutes later on this calendar only.
      let(:params) do
        {calendar_scope: "this", series_scope: "following", occurrence_start: occurrence.to_i,
         starts_at: (occurrence + 30.minutes).iso8601, ends_at: (occurrence + 90.minutes).iso8601}
      end

      it "splits the series where it is and shifts only this calendar's eventlet on the new one" do
        expect(form.save).to be(true)

        continuation = Calendars::Event.where.not(id: event.id).sole
        expect(continuation.starts_at).to eq(occurrence)
        new_eventlets = Calendars::Eventlet.where(event_id: continuation.id).index_by(&:calendar_id)
        expect(new_eventlets[calendar.id].start_offset).to eq(30.minutes.to_i)
        expect(new_eventlets[calendar2.id].start_offset).to eq(0)
        expect(eventlet.reload.start_offset).to eq(0)
        expect(event.reload.starts_at).to eq(base_start)
      end

      context "when the dragged occurrence was already shifted on this calendar" do
        # The setup shifts the fifth occurrence +15 minutes here. Shown at +15m, dropped at +45m.
        let(:occurrence) { base_start + 4.weeks }
        let(:params) do
          {calendar_scope: "this", series_scope: "following", occurrence_start: occurrence.to_i,
           starts_at: (occurrence + 45.minutes).iso8601, ends_at: (occurrence + 105.minutes).iso8601}
        end

        it "lands it at the drop" do
          expect(form.save).to be(true)

          new_eventlet = Calendars::Eventlet.find_by(calendar_id: calendar.id,
            event_id: Calendars::Event.where.not(id: event.id).sole.id)
          shown = Calendars::OccurrenceResolver.new(new_eventlet, occurrence.to_i).resolve
          expect(shown.starts_at).to eq(occurrence + 45.minutes)
          expect(shown.ends_at).to eq(occurrence + 105.minutes)
        end
      end

      context "on an event with only one calendar" do
        let(:dragged_occurrence) { nil }

        before do
          other_eventlet.destroy
          event.eventlets.reset
        end

        it "is refused" do
          expect(form.save).to be(false)
          expect(form.errors[:base]).to include("This event is only on one calendar.")
        end

        it_behaves_like "a drag that leaves the series untouched"
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
            expect(form.errors[:base].join).to match(/already started.*“This and following”/)
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

      describe "this and following" do
        let(:params) do
          {calendar_scope: "all", series_scope: "following", occurrence_start: occurrence.to_i,
           starts_at: (occurrence + 1.hour).iso8601, ends_at: (occurrence + 2.hours).iso8601}
        end

        it "is allowed from a future occurrence, leaving past ones in place" do
          expect(form.save).to be(true)
          expect(event.reload.starts_at).to eq(base_start)
          expect(event.schedule.occurrences(base_start + 5.weeks).map(&:to_time)).to eq([base_start])
        end

        context "dropped onto an earlier date" do
          # Still in the future, but earlier than where the occurrence was. "Past" goes by where the
          # occurrence was before the drag, so this is fine.
          let(:params) do
            drop = base_start + 2.days
            {calendar_scope: "all", series_scope: "following", occurrence_start: occurrence.to_i,
             starts_at: drop.iso8601, ends_at: (drop + 1.hour).iso8601}
          end

          it "is allowed" do
            expect(form.save).to be(true)
          end
        end

        context "from a past occurrence" do
          let(:dragged_occurrence) { nil }

          before { Timecop.freeze(base_start + 1.week + 1.day) }

          # The first occurrence counts as the whole series, so use the second, now also past.
          let(:params) do
            past = base_start + 1.week
            {calendar_scope: "all", series_scope: "following", occurrence_start: past.to_i,
             starts_at: (past + 2.weeks).iso8601, ends_at: (past + 2.weeks + 1.hour).iso8601}
          end

          it "refuses even an admin" do
            expect(form.save).to be(false)
            expect(form.errors[:base].join).to match(/already begun/)
          end

          it_behaves_like "a drag that leaves the series untouched"
        end

        context "from an occurrence that began a minute ago, dropped in the future" do
          let(:dragged_occurrence) { nil }

          before { Timecop.freeze(occurrence + 1.minute) }

          let(:params) do
            {calendar_scope: "all", series_scope: "following", occurrence_start: occurrence.to_i,
             starts_at: (occurrence + 1.day).iso8601, ends_at: (occurrence + 1.day + 1.hour).iso8601}
          end

          it "is refused" do
            expect(form.save).to be(false)
            expect(form.errors[:base].join).to match(/already begun/)
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

  # A resize is a drag that moves only the end. FullCalendar sends it through the same handler.
  describe "resizing" do
    def resize(target = eventlet, **params)
      described_class.new(eventlet: target, current_user: user, params: params)
    end

    it "lengthens the event on all calendars" do
      form = resize(calendar_scope: "all", series_scope: "series",
        starts_at: base_start.iso8601, ends_at: (base_end + 30.minutes).iso8601)

      expect(form.save).to be(true)
      expect(event.reload.starts_at).to eq(base_start)
      expect(event.ends_at).to eq(base_end + 30.minutes)
    end

    it "lengthens it on this calendar only" do
      Calendars::Eventlet.create!(event_id: event.id, calendar: calendar2)
      form = resize(calendar_scope: "this", series_scope: "series",
        starts_at: base_start.iso8601, ends_at: (base_end + 30.minutes).iso8601)

      expect(form.save).to be(true)
      expect(eventlet.reload.start_offset).to eq(0)
      expect(eventlet.end_offset).to eq(30.minutes.to_i)
      expect(event.reload.ends_at).to eq(base_end)
    end

    context "with a recurring event" do
      let(:occurrence) { base_start + 1.week }

      before { event.update!(recurrence_rule: IceCube::Rule.weekly.to_hash) }

      it "lengthens one occurrence on all calendars" do
        form = resize(calendar_scope: "all", series_scope: "occurrence", occurrence_start: occurrence.to_i,
          starts_at: occurrence.iso8601, ends_at: (occurrence + 90.minutes).iso8601)

        expect(form.save).to be(true)
        override = event.event_overrides.reload.sole
        expect(override.starts_at).to eq(occurrence)
        expect(override.ends_at).to eq(occurrence + 90.minutes)
      end

      it "lengthens one occurrence on this calendar only" do
        Calendars::Eventlet.create!(event_id: event.id, calendar: calendar2)
        form = resize(calendar_scope: "this", series_scope: "occurrence", occurrence_start: occurrence.to_i,
          starts_at: occurrence.iso8601, ends_at: (occurrence + 90.minutes).iso8601)

        expect(form.save).to be(true)
        override = event.event_overrides.reload.sole.eventlet_overrides.sole
        expect([override.start_offset, override.end_offset]).to eq([0, 30.minutes.to_i])
      end

      it "stretches every occurrence past midnight" do
        late = create(:eventlet, calendar: calendar, starts_at: base_start + 10.hours,
          ends_at: base_start + 11.hours)
        late.event.update!(recurrence_rule: IceCube::Rule.weekly.to_hash)
        late_occurrence = late.event.starts_at + 1.week

        form = resize(late, calendar_scope: "all", series_scope: "series",
          occurrence_start: late_occurrence.to_i, starts_at: late_occurrence.iso8601,
          ends_at: (late_occurrence + 3.hours).iso8601)

        expect(form.save).to be(true)
        expect(late.event.reload.starts_at).to eq(base_start + 10.hours)
        expect(late.event.ends_at).to eq(base_start + 13.hours)
      end
    end

    context "with an all-day event" do
      let(:day) { base_start.to_date }
      let(:eventlet) do
        create(:eventlet, calendar: calendar, all_day: true,
          starts_at: day.in_time_zone, ends_at: day.in_time_zone)
      end

      # FullCalendar posts the exclusive day-after as the end of an all-day event.
      it "stretches it over more days" do
        form = resize(calendar_scope: "all", series_scope: "series",
          starts_at: day.to_s, ends_at: (day + 3).to_s)

        expect(form.save).to be(true)
        expect(event.reload.starts_at).to eq(day.in_time_zone)
        expect(event.ends_at).to eq((day + 2).in_time_zone.end_of_day.change(usec: 0))
      end

      context "that recurs" do
        let(:occurrence) { event.starts_at + 1.week }

        before { event.update!(recurrence_rule: IceCube::Rule.weekly.to_hash) }

        it "stretches every occurrence" do
          form = resize(calendar_scope: "all", series_scope: "series", occurrence_start: occurrence.to_i,
            starts_at: occurrence.to_date.to_s, ends_at: (occurrence.to_date + 2).to_s)

          expect(form.save).to be(true)
          expect(event.reload.starts_at).to eq(day.in_time_zone)
          expect(event.ends_at).to eq((day + 1).in_time_zone.end_of_day.change(usec: 0))
        end

        it "stretches one occurrence" do
          form = resize(calendar_scope: "all", series_scope: "occurrence", occurrence_start: occurrence.to_i,
            starts_at: occurrence.to_date.to_s, ends_at: (occurrence.to_date + 2).to_s)

          expect(form.save).to be(true)
          override = event.event_overrides.reload.sole
          expect(override.starts_at).to eq(occurrence)
          expect(override.ends_at).to eq((occurrence.to_date + 1).in_time_zone.end_of_day.change(usec: 0))
        end
      end
    end
  end

  describe ".allowed_choices" do
    let(:occurrence) { base_start + 1.week }
    let(:creator) { event.creator }

    def choices(user: admin, occurrence_start: occurrence)
      described_class.allowed_choices(eventlet: eventlet, occurrence_start: occurrence_start, user: user)
    end

    it "offers only the whole event, on all calendars, for a plain event" do
      expect(choices(occurrence_start: nil)).to eq("this" => [], "all" => ["series"])
    end

    context "with a recurring event on two calendars" do
      before do
        event.update!(recurrence_rule: IceCube::Rule.weekly.to_hash)
        Calendars::Eventlet.create!(event_id: event.id, calendar: calendar2)
        event.eventlets.reset
      end

      it "offers every choice on a later occurrence of a series that hasn't started" do
        all_three = %w[occurrence following series]
        expect(choices).to eq("this" => all_three, "all" => all_three)
      end

      it "doesn't offer “This and following” on the first occurrence" do
        expect(choices(occurrence_start: base_start)["all"]).to eq(%w[occurrence series])
      end

      context "once the series has started" do
        before { Timecop.freeze(base_start + 1.day) }
        after { Timecop.return }

        it "offers this and following occurrences, but not all of them" do
          expect(choices(user: creator)["all"]).to eq(%w[occurrence following])
          expect(choices["all"]).to eq(%w[occurrence following])
        end

        it "lets only an admin move a past occurrence, and only by itself" do
          expect(choices(occurrence_start: base_start)["all"]).to eq(%w[occurrence])
          expect(choices(user: creator, occurrence_start: base_start)).to eq("this" => [], "all" => [])
        end

        it "explains why nothing can be moved" do
          refusal = described_class.refusal(eventlet: eventlet, occurrence_start: base_start, user: creator)
          expect(refusal.errors[:starts_at]).to include("can't be changed after event begins")
        end

        it "still offers all occurrences on a series created moments ago" do
          event.update_columns(created_at: 10.minutes.ago)
          expect(choices["all"]).to include("series")
        end
      end
    end

    context "with a recurring event on one calendar" do
      before { event.update!(recurrence_rule: IceCube::Rule.weekly.to_hash) }

      it "offers nothing on this calendar only, since there's no calendar question" do
        expect(choices["this"]).to be_empty
      end
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
