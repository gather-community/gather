# frozen_string_literal: true

require "rails_helper"

# Covers dragging (and resizing) an event on the calendar grid, which sends an XHR update to
# EventsController#update. The grid feed is eventlet-centric: the serialized FullCalendar `id` is the
# eventlet id, but the update endpoint is keyed by event id, so the drag handler must send the event id.
describe "dragging a calendar event", js: true do
  let(:actor) { create(:user) }
  let(:calendar) { create(:calendar, selected_by_default: true) }

  # Next-week noon so the event is comfortably in the future (avoids the can't-change-the-past rule)
  # and visible after a single click on "next week".
  let(:starts_at) { Time.current.next_week(:wednesday) + 12.hours }

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

  let!(:event) do
    create(:event, calendar: calendar, creator: actor, name: "Draggable",
      starts_at: starts_at, ends_at: starts_at + 1.hour)
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
    accept_confirm { drag_vertically(find(".fc-event", text: "Draggable"), by: 140) }

    expect(eventually { event.reload.starts_at > starts_at }).to(
      be(true), "Expected the event to move to a later time, but starts_at stayed #{event.reload.starts_at}"
    )
  end

  scenario "cancelling the move leaves the event untouched" do
    dismiss_confirm { drag_vertically(find(".fc-event", text: "Draggable"), by: 140) }

    # Give any (erroneously fired) request time to land, then confirm nothing changed.
    sleep(1)
    expect(event.reload.starts_at).to be_within(1.second).of(starts_at)
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
