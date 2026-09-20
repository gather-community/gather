# frozen_string_literal: true

require "rails_helper"

# Covers dragging (and resizing) an event on the calendar grid, which sends an XHR update to
# EventletsController#update. The grid feed is eventlet-centric, so the serialized FullCalendar `id`
# is the eventlet id, which is what the drag handler posts.
#
# A drag asks up to two scope questions before saving: which calendars (only when the event spans
# more than one) and which occurrences (only when it recurs). When neither applies it falls back to
# a plain confirmation.
describe "dragging a calendar event", js: true do
  let(:actor) { create(:user) }
  let(:calendar) { create(:calendar, selected_by_default: true) }

  # Next-week noon so the event is comfortably in the future (avoids the can't-change-the-past rule)
  # and visible after a single click on "next week". FullCalendar's week view starts on Sunday, so we
  # compute the target off a Sunday-based week (not Rails' Monday default) — otherwise on Sundays the
  # event would fall in the currently-shown week and the single "next" click would scroll past it.
  let(:starts_at) { Time.current.beginning_of_week(:sunday) + 1.week + 3.days + 12.hours }

  # Production eventlet ids are not aligned with event ids (eventlets were backfilled for pre-existing
  # events). In a fresh test DB the first event would get event.id == eventlet.id, masking a drag
  # handler that posts the eventlet id to the event endpoint. Advancing only the eventlet sequence
  # forces the two to diverge, the way they do in prod.
  let!(:divergence) do
    decoy = create(:event)
    # A second eventlet on the decoy event (on a different calendar, to satisfy the uniqueness index)
    # advances only the eventlet sequence, not the event sequence.
    create(:eventlet, event: decoy, calendar: create(:calendar))
  end

  # Overridden by the contexts below. These have to be declared out here, not in the contexts, so
  # that they're built before the `before` block visits the page — an inner-context `let!` runs after
  # an outer-context `before`, which would leave the feed showing a plain single-calendar event.
  let(:recurrence) { nil }
  let(:second_calendar) { nil }

  let!(:event) do
    create(:event, calendar: calendar, creator: actor, name: "Draggable",
      starts_at: starts_at, ends_at: starts_at + 1.hour, recurrence_rule: recurrence)
  end

  let!(:other_eventlet) do
    second_calendar && Calendars::Eventlet.create!(event_id: event.id, calendar: second_calendar)
  end

  before do
    # Sanity check the divergence setup so a future factory change can't silently neuter this spec.
    expect(event.eventlets.first.id).not_to eq(event.id)

    use_user_subdomain(actor)
    login_as(actor, scope: :user)
    visit(calendar_events_path(calendar))
    find(".fc-next-button").click
    expect(page).to have_css(".fc-event", text: "Draggable")
  end

  scenario "confirming the move persists the new time" do
    drag_vertically(find(".fc-event", text: "Draggable"), by: 140)
    click_modal_button

    expect(eventually { event.reload.starts_at > starts_at }).to(
      be(true), "Expected the event to move to a later time, but starts_at stayed #{event.reload.starts_at}"
    )
  end

  scenario "cancelling the move leaves the event untouched" do
    drag_vertically(find(".fc-event", text: "Draggable"), by: 140)
    click_modal_button(I18n.t("modal.cancel"))

    # Give any (erroneously fired) request time to land, then confirm nothing changed.
    sleep(1)
    expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
  end

  context "with an event on more than one calendar" do
    let(:calendar2) { create(:calendar, selected_by_default: true) }
    let(:second_calendar) { calendar2 }

    scenario "moving on this calendar only shifts that eventlet's offset" do
      drag_vertically(find(".fc-event", text: "Draggable", match: :first), by: 140)
      click_modal_button("Move only on #{calendar.name}")

      expect(eventually { event.eventlets.find_by(calendar_id: calendar.id).start_offset.positive? })
        .to be(true), "Expected this calendar's eventlet to gain a positive start_offset"
      expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
      expect(other_eventlet.reload.start_offset).to eq(0)
    end

    scenario "moving on all calendars shifts the event itself" do
      drag_vertically(find(".fc-event", text: "Draggable", match: :first), by: 140)
      click_modal_button("Move on all")

      expect(eventually { event.reload.starts_at > starts_at })
        .to be(true), "Expected the event itself to move, but starts_at stayed #{event.reload.starts_at}"
      expect(other_eventlet.reload.start_offset).to eq(0)
    end

    scenario "cancelling at the calendar prompt leaves everything untouched" do
      drag_vertically(find(".fc-event", text: "Draggable", match: :first), by: 140)
      click_modal_button(I18n.t("modal.cancel"))

      sleep(1)
      expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
      expect(event.eventlets.pluck(:start_offset)).to all(eq(0))
    end
  end

  context "with a recurring event" do
    let(:recurrence) { IceCube::Rule.weekly.to_hash }

    scenario "moving only this occurrence creates an override and leaves the series alone" do
      drag_vertically(find(".fc-event", text: "Draggable", match: :first), by: 140)
      click_modal_button("Only this occurrence")

      expect(eventually { event.event_overrides.any? })
        .to be(true), "Expected an EventOverride to be created for the dragged occurrence"
      expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
    end

    scenario "moving the whole series shifts the event itself" do
      drag_vertically(find(".fc-event", text: "Draggable", match: :first), by: 140)
      click_modal_button("The whole series")

      expect(eventually { event.reload.starts_at > starts_at })
        .to be(true), "Expected the series anchor to move, but starts_at stayed #{event.reload.starts_at}"
      expect(event.event_overrides).to be_empty
    end
  end

  # Simulates a real mouse drag of a FullCalendar (jQuery-UI-based) event. HTML5 drag_to does not work
  # with FullCalendar, so we drive the pointer directly with intermediate moves to trigger the drag.
  def drag_vertically(element, by:)
    step = (by / 4.0).round
    page.driver.browser.action
      .move_to(element.native)
      .pause(duration: 0.1)
      .click_and_hold
      .pause(duration: 0.1)
      .move_by(0, step).pause(duration: 0.1)
      .move_by(0, step).pause(duration: 0.1)
      .move_by(0, step).pause(duration: 0.1)
      .move_by(0, by - 3 * step).pause(duration: 0.1)
      .release
      .perform
  end

  # Polls the block until it returns truthy or the timeout elapses (the DB update lands asynchronously
  # after the XHR completes, so Capybara's own waiting doesn't cover it).
  def eventually(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return true if yield
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep(0.1)
    end
  end
end
