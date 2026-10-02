# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventletDeletionForm do
  let(:admin) { create(:admin) }
  let(:creator) { create(:user) }
  let(:calendar) { create(:calendar, name: "Main Hall") }
  let(:calendar2) { create(:calendar, name: "Guest Room") }

  # Weekly at 6pm, starting next week so no occurrence is in the past.
  let(:series_start) { Time.zone.now.next_week.midnight + 18.hours }
  let(:rule) { IceCube::Rule.weekly.to_hash }
  let(:all_day) { false }
  let!(:event) do
    create(:event, calendar: calendar, creator: creator, all_day: all_day, recurrence_rule: rule,
      starts_at: series_start, ends_at: series_start + 1.hour)
  end
  let(:eventlet) { event.eventlets.detect { |e| e.calendar_id == calendar.id } }

  def occ(n)
    series_start + n.weeks
  end

  def build_form(calendar_scope:, series_scope:, occurrence: nil, user: admin, target: eventlet)
    params = ActionController::Parameters.new(calendar_scope: calendar_scope, series_scope: series_scope,
      occurrence_start: occurrence&.to_i)
    described_class.new(eventlet: target, current_user: user, params: params)
  end

  # Start times shown on the grid, read back through the real display path.
  def visible_starts(on: calendar, weeks: 8)
    range = (series_start - 1.day)..(series_start + weeks.weeks)
    Calendars::EventFinder.new(range: range, calendars: [on], user: admin).eventlets.map(&:starts_at)
  end

  # Created through the association so an already-loaded event.eventlets sees it.
  def add_second_calendar
    event.eventlets.create!(calendar: calendar2)
  end

  describe "all calendars + this occurrence" do
    it "hides just that occurrence" do
      expect(build_form(calendar_scope: "all", series_scope: "occurrence",
        occurrence: occ(2)).save).to be(true)

      expect(visible_starts).to include(occ(1), occ(3))
      expect(visible_starts).not_to include(occ(2))
      expect(event.event_overrides.sole).to have_attributes(deleted: true, occurrence_start: occ(2))
    end

    it "hides it on every calendar" do
      add_second_calendar
      build_form(calendar_scope: "all", series_scope: "occurrence", occurrence: occ(2)).save
      expect(visible_starts(on: calendar2)).not_to include(occ(2))
    end

    it "clears any earlier move and per-calendar change" do
      override = create(:event_override, event: event, occurrence_start: occ(2),
        starts_at: occ(2) + 2.hours, ends_at: occ(2) + 3.hours)
      create(:eventlet_override, event_override: override, eventlet: eventlet, start_offset: 600)

      build_form(calendar_scope: "all", series_scope: "occurrence", occurrence: occ(2)).save

      expect(override.reload).to have_attributes(deleted: true, starts_at: nil, ends_at: nil)
      expect(override.eventlet_overrides).to be_empty
      expect(visible_starts).not_to include(occ(2) + 2.hours)
    end
  end

  describe "all calendars + this and following" do
    it "ends a never-ending series with the previous occurrence" do
      expect(build_form(calendar_scope: "all", series_scope: "following",
        occurrence: occ(2)).save).to be(true)

      event.reload
      expect(visible_starts).to eq([occ(0), occ(1)])
      expect(event.recurrence_end_date).to eq(occ(1).to_date)
    end

    context "with a count rule" do
      let(:rule) { IceCube::Rule.weekly.count(10).to_hash }

      it "replaces the count with an end date" do
        build_form(calendar_scope: "all", series_scope: "following", occurrence: occ(3)).save

        event.reload
        expect(event.schedule.rrules.first.occurrence_count).to be_nil
        expect(visible_starts(weeks: 12)).to eq([occ(0), occ(1), occ(2)])
        expect(event.recurrence_end_date).to eq(occ(2).to_date)
      end
    end

    context "with an until rule" do
      let(:rule) { IceCube::Rule.weekly.until(series_start + 8.weeks).to_hash }

      it "moves the end date earlier" do
        build_form(calendar_scope: "all", series_scope: "following", occurrence: occ(3)).save
        expect(visible_starts(weeks: 12)).to eq([occ(0), occ(1), occ(2)])
      end
    end

    it "drops overrides at or after the cutoff and keeps earlier ones" do
      earlier = create(:event_override, event: event, occurrence_start: occ(1), deleted: true)
      at_cutoff = create(:event_override, event: event, occurrence_start: occ(2), deleted: true)
      later = create(:event_override, event: event, occurrence_start: occ(4),
        starts_at: occ(4) + 1.hour, ends_at: occ(4) + 2.hours)

      build_form(calendar_scope: "all", series_scope: "following", occurrence: occ(2)).save

      expect(Calendars::EventOverride.exists?(earlier.id)).to be(true)
      expect(Calendars::EventOverride.exists?(at_cutoff.id)).to be(false)
      expect(Calendars::EventOverride.exists?(later.id)).to be(false)
    end

    it "deletes the whole event when starting from the first occurrence" do
      form = build_form(calendar_scope: "all", series_scope: "following", occurrence: occ(0))
      expect(form.effective_series_scope).to eq("series")
      form.save
      expect(Calendars::Event.exists?(event.id)).to be(false)
    end

    context "with an all-day series" do
      let(:all_day) { true }

      it "keeps the days before the cutoff" do
        build_form(calendar_scope: "all", series_scope: "following", occurrence: occ(2).midnight).save

        event.reload
        expect(visible_starts.map(&:to_date)).to eq([occ(0).to_date, occ(1).to_date])
        expect(event.recurrence_end_date).to eq(occ(1).to_date)
      end
    end

    context "with an evening series in a zone west of UTC, crossing a DST change" do
      # Nov 3 2030 is the end of DST in Toronto. 9pm local is the next day in UTC.
      let(:series_start) { Time.zone.parse("2030-10-21 21:00") }

      around { |example| Time.use_zone("America/Toronto") { example.run } }

      it "keeps local wall-clock times and the local end date" do
        build_form(calendar_scope: "all", series_scope: "following", occurrence: occ(3)).save

        event.reload
        expect(visible_starts.map { |t| t.strftime("%m-%d %H:%M") })
          .to eq(["10-21 21:00", "10-28 21:00", "11-04 21:00"])
        expect(event.recurrence_end_date).to eq(Date.new(2030, 11, 4))
      end
    end
  end

  describe "all calendars + whole series" do
    it "destroys the event" do
      expect(build_form(calendar_scope: "all", series_scope: "series").save).to be(true)
      expect(Calendars::Event.exists?(event.id)).to be(false)
    end
  end

  describe "this calendar + this occurrence" do
    let!(:other_eventlet) { add_second_calendar }

    it "hides the occurrence on this calendar only" do
      form = build_form(calendar_scope: "this", series_scope: "occurrence", occurrence: occ(2))
      expect(form.save).to be(true)

      expect(visible_starts).not_to include(occ(2))
      expect(visible_starts(on: calendar2)).to include(occ(2))
      anchor = event.event_overrides.sole
      expect(anchor.deleted).to be(false)
      expect(anchor.eventlet_overrides.sole).to have_attributes(eventlet_id: eventlet.id, deleted: true)
    end

    it "reuses an existing per-calendar change" do
      anchor = create(:event_override, event: event, occurrence_start: occ(2))
      existing = create(:eventlet_override, event_override: anchor, eventlet: eventlet, start_offset: 600)

      build_form(calendar_scope: "this", series_scope: "occurrence", occurrence: occ(2)).save

      expect(existing.reload).to have_attributes(deleted: true, start_offset: nil)
      expect(Calendars::EventletOverride.count).to eq(1)
    end
  end

  describe "this calendar + whole series" do
    let!(:other_eventlet) { add_second_calendar }

    it "removes the event from this calendar only" do
      expect(build_form(calendar_scope: "this", series_scope: "series",
        target: other_eventlet).save).to be(true)

      expect(Calendars::Eventlet.exists?(other_eventlet.id)).to be(false)
      expect(event.reload.calendar).to eq(calendar)
      expect(visible_starts).to include(occ(0))
    end

    it "moves the event to a remaining calendar when removing it from its own" do
      build_form(calendar_scope: "this", series_scope: "series").save

      expect(event.reload.calendar).to eq(calendar2)
      expect(visible_starts(on: calendar2)).to include(occ(0))
    end
  end

  describe "validation" do
    it "rejects this calendar + following" do
      add_second_calendar
      form = build_form(calendar_scope: "this", series_scope: "following", occurrence: occ(2))
      expect(form).not_to be_valid
    end

    it "rejects this calendar when the event is only on one" do
      expect(build_form(calendar_scope: "this", series_scope: "series")).not_to be_valid
    end

    it "rejects a time that isn't an occurrence of the series" do
      form = build_form(calendar_scope: "all", series_scope: "occurrence", occurrence: occ(2) + 1.hour)
      expect(form).not_to be_valid
      expect(form.errors[:occurrence_start]).to be_present
    end

    it "requires an occurrence for an occurrence delete, rather than defaulting to the first" do
      form = build_form(calendar_scope: "all", series_scope: "occurrence")
      expect(form).not_to be_valid
      expect(form.authorization_targets).to be_empty
    end

    it "rejects an occurrence delete on a non-recurring event" do
      event.update!(recurrence_rule: nil)
      expect(build_form(calendar_scope: "all", series_scope: "occurrence",
        occurrence: occ(0))).not_to be_valid
    end
  end

  describe "#authorization_targets" do
    it "is the event for a whole-series delete" do
      expect(build_form(calendar_scope: "all", series_scope: "series").authorization_targets).to eq([event])
    end

    it "is the resolved occurrence on each calendar for an all-calendars occurrence delete" do
      add_second_calendar
      targets = build_form(calendar_scope: "all", series_scope: "occurrence", occurrence: occ(2))
        .authorization_targets
      expect(targets.map(&:calendar)).to contain_exactly(calendar, calendar2)
      expect(targets.map(&:starts_at).uniq).to eq([occ(2)])
    end

    it "is empty when the occurrence was already deleted" do
      create(:event_override, event: event, occurrence_start: occ(2), deleted: true)
      form = build_form(calendar_scope: "all", series_scope: "occurrence", occurrence: occ(2))
      expect(form).to be_target_missing
    end

    it "is empty for an unknown combination" do
      expect(build_form(calendar_scope: "this", series_scope: "following").authorization_targets).to be_empty
    end
  end

  describe ".allowed_choices" do
    def choices(user:, occurrence:)
      described_class.allowed_choices(eventlet: eventlet, occurrence_start: occurrence, user: user)
    end

    context "for a series that has already started" do
      let(:series_start) { 2.weeks.ago.midnight + 18.hours }

      before do
        event.update_columns(created_at: 1.month.ago)
        eventlet.update_columns(created_at: 1.month.ago)
      end

      it "lets the creator delete a future occurrence or the rest of the series, but not all of it" do
        expect(choices(user: creator,
          occurrence: occ(3))).to eq("this" => [], "all" => %w[occurrence following])
      end

      it "doesn't let the creator delete a past occurrence" do
        expect(choices(user: creator, occurrence: occ(0))).to eq("this" => [], "all" => [])
      end

      it "lets an admin do anything, but doesn't offer following from the first occurrence" do
        expect(choices(user: admin, occurrence: occ(3))["all"]).to eq(%w[occurrence following series])
        expect(choices(user: admin, occurrence: occ(0))["all"]).to eq(%w[occurrence series])
      end

      it "lets a calendar coordinator do anything" do
        coordinator = create(:calendar_coordinator)
        expect(choices(user: coordinator, occurrence: occ(3))["all"]).to eq(%w[occurrence following series])
      end

      it "doesn't let an unrelated user delete anything" do
        expect(choices(user: create(:user), occurrence: occ(3))).to eq("this" => [], "all" => [])
      end
    end

    context "for a series created moments ago" do
      it "lets the creator delete all of it" do
        expect(choices(user: creator, occurrence: occ(3))["all"]).to eq(%w[occurrence following series])
      end
    end

    context "when the event's other calendar is read-only for the creator" do
      let(:other_community) { create(:community) }
      let(:calendar2) { create(:calendar, community: other_community) }

      before do
        create(:calendar_protocol, calendars: [calendar2], other_communities: "read_only")
        add_second_calendar
      end

      it "only offers deleting from the creator's own calendar" do
        expect(choices(user: creator, occurrence: occ(3))).to eq("this" => %w[occurrence series], "all" => [])
      end
    end
  end
end
