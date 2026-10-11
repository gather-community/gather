# frozen_string_literal: true

require "rails_helper"

# Covers dragging (and resizing) an event on the calendar grid, which sends an XHR update to
# EventletsController#update. The grid feed is eventlet-centric, so the serialized FullCalendar `id`
# is the eventlet id, which is what the drag handler posts.
#
# Before asking anything, a drag fetches the choices this user may make right now
# (EventletsController#move_choices). Then it asks up to two questions: which calendars (only when
# both calendar choices are allowed) and which occurrences (only when the event recurs and there's
# more than one choice). When no question is needed it falls back to a plain confirmation.
#
# All-day and month-view drags are in drag_all_day_spec.rb; fixed-time calendars in
# drag_fixed_times_spec.rb.
describe "dragging a calendar event", js: true do
  let(:actor) { create(:user) }
  let(:event_creator) { actor }
  let(:event_name) { "Draggable" }
  let(:calendar) { create(:calendar, selected_by_default: true) }

  # Next-week noon so the event is comfortably in the future (avoids the can't-change-the-past rule)
  # and visible after a single click on "next week". FullCalendar's week view starts on Sunday, so we
  # compute the target off a Sunday-based week (not Rails' Monday default) — otherwise on Sundays the
  # event would fall in the currently-shown week and the single "next" click would scroll past it.
  let(:starts_at) { Time.current.beginning_of_week(:sunday) + 1.week + 3.days + 12.hours }

  # Production eventlet ids are not aligned with event ids (eventlets were backfilled for pre-existing
  # events). In a fresh test DB an event and its eventlet can share an id, masking a drag handler that
  # posts the eventlet id to the event endpoint. Force the eventlet id sequence well ahead of the
  # event id sequence so the two diverge the way they do in prod. This has to be explicit: Postgres
  # sequences aren't rolled back between examples, so any earlier spec's records shift the gap
  # unpredictably (a decoy-record trick flakes on run order). GREATEST keeps the sequence from ever
  # moving backward onto an existing id.
  let!(:divergence) { diverge_eventlet_ids! }

  # Overridden by the contexts below. These have to be declared out here, not in the contexts, so
  # that they're built before the `before` block visits the page — an inner-context `let!` runs after
  # an outer-context `before`, which would leave the feed showing a plain single-calendar event.
  let(:recurrence) { nil }
  let(:second_calendar) { nil }
  let(:page_path) { calendar_events_path(calendar) }
  let(:setup_before_visit) { nil }

  let!(:event) do
    create(:event, calendar: calendar, creator: event_creator, name: event_name,
      starts_at: starts_at, ends_at: starts_at + 1.hour, recurrence_rule: recurrence)
  end

  let!(:other_eventlet) do
    second_calendar && Calendars::Eventlet.create!(event_id: event.id, calendar: second_calendar)
  end

  before do
    # Sanity check the divergence setup so a future factory change can't silently neuter this spec.
    expect(event.eventlets.first.id).not_to eq(event.id)
    setup_before_visit

    use_user_subdomain(actor)
    login_as(actor, scope: :user)
    visit(page_path)
    find(".fc-next-button").click
    expect(page).to have_css(".fc-event", text: event_name)
  end

  def draggable
    find(".fc-event", text: event_name, match: :first)
  end

  # Gives any (erroneously fired) request time to land, then checks the event didn't change.
  def expect_unchanged
    sleep(1)
    expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
    expect(event.ends_at).to be_within(1.second).of(starts_at + 1.hour)
    expect(event.event_overrides).to be_empty
    expect(Calendars::Event.where.not(id: event.id).where(name: event_name)).to be_empty
  end

  scenario "confirming the move persists the new time" do
    drag_vertically(draggable, by: 140)
    click_modal_button

    expect(eventually { event.reload.starts_at > starts_at }).to(
      be(true), "Expected the event to move to a later time, but starts_at stayed #{event.reload.starts_at}"
    )
  end

  scenario "cancelling the move leaves the event untouched" do
    drag_vertically(draggable, by: 140)
    click_modal_button(I18n.t("modal.cancel"))
    expect_unchanged
  end

  scenario "dragging to another day keeps the time" do
    drag_horizontally(draggable, columns: 1)
    click_modal_button

    expect(eventually { event.reload.starts_at.to_date == (starts_at + 1.day).to_date })
      .to be(true), "Expected the event to move to the next day, but it starts #{event.reload.starts_at}"
    expect(event.starts_at).to be_within(1.second).of(starts_at + 1.day)
  end

  scenario "resizing an event changes its end but not its start" do
    resize_vertically(draggable, by: 80)
    click_modal_button

    expect(eventually { event.reload.ends_at > starts_at + 1.hour })
      .to be(true), "Expected the end to move later, but ends_at stayed #{event.reload.ends_at}"
    expect(event.starts_at).to be_within(1.second).of(starts_at)
  end

  context "with HTML in the event's name" do
    let(:event_name) { "Draggable <b>x</b>" }

    scenario "shows the name as text in the modal" do
      drag_vertically(draggable, by: 140)

      expect(page).to have_css(modal_selector, text: "Draggable <b>x</b>")
      expect(page).not_to have_css("#{modal_selector} b")
      click_modal_button(I18n.t("modal.cancel"))
    end
  end

  context "with an event the user can't edit" do
    let(:event_creator) { create(:user) }

    scenario "can't be dragged" do
      drag_vertically(draggable, by: 140)

      expect(page).not_to have_css(modal_selector)
      expect_unchanged
    end
  end

  context "on the combined calendar page" do
    let(:page_path) { calendars_events_path }

    scenario "drags work the same way" do
      drag_vertically(draggable, by: 140)
      click_modal_button

      expect(eventually { event.reload.starts_at > starts_at })
        .to be(true), "Expected the event to move, but starts_at stayed #{event.reload.starts_at}"
    end
  end

  context "on a calendar that doesn't allow overlaps" do
    let(:calendar) { create(:calendar, selected_by_default: true, allow_overlap: false) }
    # Covers the whole afternoon, so any drop below the event lands on it.
    let(:setup_before_visit) do
      create(:event, calendar: calendar, name: "Blocker", starts_at: starts_at + 90.minutes,
        ends_at: starts_at + 8.hours)
    end

    scenario "a drop onto another event is blocked without asking or saving" do
      drag_vertically(draggable, by: 140)

      expect(page).not_to have_css(modal_selector)
      expect_unchanged
    end
  end

  context "on a calendar whose protocol limits events to an hour" do
    let(:setup_before_visit) { create(:calendar_protocol, calendars: [calendar], max_length_minutes: 60) }

    scenario "lengthening an event past the limit is refused with the reason" do
      resize_vertically(draggable, by: 80)
      click_modal_button

      expect(page).to have_css(modal_selector, text: "Can be at most 1 hour after start time")
      click_modal_button("Close")
      expect_unchanged
    end
  end

  context "when the move choices can't be loaded" do
    around do |example|
      raise_server_errors = Capybara.raise_server_errors
      Capybara.raise_server_errors = false
      example.run
    ensure
      Capybara.raise_server_errors = raise_server_errors
    end

    scenario "says so and puts the event back" do
      allow(Calendars::EventletForm).to receive(:allowed_choices).and_raise("Simulated failure")
      drag_vertically(draggable, by: 140)

      expect(page).to have_css(modal_selector, text: "We couldn't check how this event can be moved")
      click_modal_button("Close")
      expect_unchanged
    end
  end

  context "with an event on more than one calendar" do
    let(:calendar2) { create(:calendar, selected_by_default: true) }
    let(:second_calendar) { calendar2 }

    scenario "moving on this calendar only shifts that eventlet's offset" do
      drag_vertically(draggable, by: 140)
      click_modal_button("Move only on #{calendar.name}")

      expect(eventually { event.eventlets.find_by(calendar_id: calendar.id).start_offset.positive? })
        .to be(true), "Expected this calendar's eventlet to gain a positive start_offset"
      expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
      expect(other_eventlet.reload.start_offset).to eq(0)
    end

    scenario "moving on all calendars shifts the event itself" do
      drag_vertically(draggable, by: 140)
      click_modal_button("Move on all")

      expect(eventually { event.reload.starts_at > starts_at })
        .to be(true), "Expected the event itself to move, but starts_at stayed #{event.reload.starts_at}"
      expect(other_eventlet.reload.start_offset).to eq(0)
    end

    scenario "cancelling at the calendar prompt leaves everything untouched" do
      drag_vertically(draggable, by: 140)
      click_modal_button(I18n.t("modal.cancel"))

      expect_unchanged
      expect(event.eventlets.pluck(:start_offset)).to all(eq(0))
    end

    context "that recurs" do
      let(:recurrence) { IceCube::Rule.weekly.to_hash }

      scenario "asks the calendar question, then the series question, and moves this and following here" do
        find(".fc-next-button").click
        drag_vertically(draggable, by: 140)
        click_modal_button("Move only on #{calendar.name}")
        expect(modal_button_labels).to eq(["Cancel", "This only", "This and following", "All occurrences"])
        click_modal_button("This and following")

        expect(eventually { Calendars::Event.where.not(id: event.id).any? })
          .to be(true), "Expected the series to be split"
        split_off = Calendars::Event.where.not(id: event.id).sole
        expect(split_off.starts_at).to be_within(1.second).of(starts_at + 1.week)
        expect(split_off.eventlets.find_by(calendar_id: calendar.id).start_offset).to be_positive
        expect(split_off.eventlets.find_by(calendar_id: calendar2.id).start_offset).to eq(0)
        expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
      end
    end
  end

  context "with a recurring event" do
    let(:recurrence) { IceCube::Rule.weekly.to_hash }

    scenario "moving only this occurrence creates an override and leaves the series alone" do
      drag_vertically(draggable, by: 140)
      click_modal_button("This only")

      expect(eventually { event.event_overrides.any? })
        .to be(true), "Expected an EventOverride to be created for the dragged occurrence"
      expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
    end

    scenario "moving all occurrences from a later one shifts the series without re-anchoring it" do
      # Show the second occurrence, so a re-anchoring bug can't hide behind dragging the first.
      find(".fc-next-button").click
      drag_vertically(draggable, by: 140)
      click_modal_button("All occurrences")

      expect(eventually { event.reload.starts_at > starts_at })
        .to be(true), "Expected the series to move, but starts_at stayed #{event.reload.starts_at}"
      expect(event.starts_at.to_date).to eq(starts_at.to_date),
        "Expected the series to keep its first occurrence, but it now starts #{event.starts_at}"
      expect(event.event_overrides).to be_empty
    end

    scenario "moving this and following occurrences leaves earlier ones in place" do
      find(".fc-next-button").click
      drag_vertically(draggable, by: 140)
      click_modal_button("This and following")

      expect(eventually { Calendars::Event.where.not(id: event.id).any? })
        .to be(true), "Expected the series to be split into a new, moved series"
      split_off = Calendars::Event.where.not(id: event.id).sole
      expect(split_off.starts_at).to be > starts_at + 1.week
      expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
      expect(event.schedule.occurrences(starts_at + 5.weeks).size).to eq(1)
    end

    scenario "offers only the choices that apply to the dragged occurrence" do
      # The first occurrence: "This and following" would mean the same as all of them.
      drag_vertically(draggable, by: 140)
      expect(modal_button_labels).to eq(["Cancel", "This only", "All occurrences"])
      click_modal_button("Cancel")

      find(".fc-next-button").click
      drag_vertically(draggable, by: 140)
      expect(modal_button_labels).to eq(["Cancel", "This only", "This and following", "All occurrences"])
      click_modal_button("Cancel")
    end

    scenario "cancelling at the series question leaves everything untouched" do
      find(".fc-next-button").click
      drag_vertically(draggable, by: 140)
      click_modal_button("Cancel")
      expect_unchanged
    end

    scenario "resizing one occurrence asks which occurrences, then lengthens only that one" do
      find(".fc-next-button").click
      resize_vertically(draggable, by: 80)
      click_modal_button("This only")

      expect(eventually { event.event_overrides.any? }).to be(true), "Expected an override for the occurrence"
      override = event.event_overrides.sole
      expect(override.starts_at).to be_within(1.second).of(starts_at + 1.week)
      expect(override.ends_at).to be > starts_at + 1.week + 1.hour
      expect(event.reload.ends_at).to be_within(1.second).of(starts_at + 1.hour)
    end

    scenario "a move that's no longer allowed is refused when the modal would open" do
      # Deleted elsewhere after the grid loaded.
      create(:event_override, event: event, occurrence_start: starts_at, deleted: true)

      drag_vertically(draggable, by: 140)

      expect(page).to have_css(modal_selector, text: "This occurrence no longer exists")
      click_modal_button("Close")
      # The refetch drops the deleted occurrence from the grid.
      expect(page).not_to have_css(".fc-event", text: event_name)
    end

    scenario "a move refused on submit shows why, reverts, and reloads the grid" do
      drag_vertically(draggable, by: 140)
      expect(modal_button_labels).to include("This only")
      # Deleted elsewhere while the modal was open, so the server refuses the drag.
      create(:event_override, event: event, occurrence_start: starts_at, deleted: true)
      click_modal_button("This only")

      expect(page).to have_css(modal_selector, text: "This occurrence no longer exists")
      click_modal_button("Close")
      expect(page).not_to have_css(".fc-event", text: event_name)
    end

    # Moving the clock after the grid has loaded, rather than before, is the point: the grid knows
    # nothing about the change, but the modal still offers only what's allowed now. Travel, not
    # freeze, so the browser and server keep ticking.
    context "when the series starts while the grid is open" do
      before { Timecop.travel(starts_at + 1.minute) }
      after { Timecop.return }

      scenario "a later occurrence offers only this one, or this and following" do
        find(".fc-next-button").click
        drag_vertically(draggable, by: 140)
        expect(modal_button_labels).to eq(["Cancel", "This only", "This and following"])
      end
    end

    context "once the first occurrence has passed" do
      before { Timecop.travel(starts_at + 1.day) }
      after { Timecop.return }

      scenario "the creator can't move it, and is told why straight away" do
        drag_vertically(draggable, by: 140)

        expect(page).to have_css(modal_selector, text: "can't be changed after event begins")
        click_modal_button("Close")
        expect_unchanged
      end

      context "as an admin" do
        let(:actor) { create(:admin) }

        scenario "with only one choice allowed, just confirms moving this occurrence" do
          drag_vertically(draggable, by: 140)

          expect(page).to have_css(modal_selector,
            text: "Are you sure you want to move this occurrence of 'Draggable'?")
          click_modal_button

          expect(eventually { event.event_overrides.any? })
            .to be(true), "Expected an override for the past occurrence"
          expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
        end
      end
    end
  end
end
