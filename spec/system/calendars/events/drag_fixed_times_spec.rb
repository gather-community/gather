# frozen_string_literal: true

require "rails_helper"

# When a calendar's protocol fixes the start and/or end time, dragging an existing event applies
# those fixed times client-side before saving, the same as creating one by selection does. This is
# the drag-path snap: the drop pushes the end past the fixed 17:00, and without the snap the server
# would reject the off-time end and the drag would revert. With it, the end is pinned back to 17:00
# and the move is accepted, so the start moves while the end stays put.
describe "dragging an event on a fixed-time calendar", js: true do
  let(:actor) { create(:user) }
  let(:calendar) { create(:calendar, selected_by_default: true) }

  # Pins the end time to 17:00. The drag handler reads this from the rule set the single-calendar
  # page serializes for the client.
  let!(:protocol) { create(:calendar_protocol, calendars: [calendar], fixed_end_time: "17:00") }

  # Next week (future, dodging the past-change rule) on a weekday that shows after one "next" click.
  # A Sunday-based week matches FullCalendar so the event never lands in the currently-shown week.
  let(:starts_at) { Time.current.beginning_of_week(:sunday) + 1.week + 3.days + 13.hours }
  let(:ends_at) { starts_at.change(hour: 17) }

  # Production eventlet ids aren't aligned with event ids (eventlets were backfilled). Advancing only
  # the eventlet sequence forces the divergence so a handler posting the wrong id would be caught.
  let!(:divergence) do
    decoy = create(:event)
    create(:eventlet, event: decoy, calendar: create(:calendar))
  end

  let!(:event) do
    create(:event, calendar: calendar, creator: actor, name: "Fixed",
      starts_at: starts_at, ends_at: ends_at)
  end

  before do
    expect(event.eventlets.first.id).not_to eq(event.id)

    use_user_subdomain(actor)
    login_as(actor, scope: :user)
    visit(calendar_events_path(calendar))
    find(".fc-next-button").click
    expect(page).to have_css(".fc-event", text: "Fixed")
  end

  scenario "snaps the end back to the fixed time so the move is accepted" do
    drag_vertically(find(".fc-event", text: "Fixed"), by: 140)
    click_modal_button

    expect(eventually { event.reload.starts_at > starts_at }).to(
      be(true), "Expected the start to move later, but starts_at stayed #{event.reload.starts_at}"
    )
    # The dropped end sat past 17:00; snapping pinned it back to the fixed time.
    expect(event.reload.ends_at).to eq(ends_at)
  end

  # Mirrors the helpers in drag_spec.rb: FullCalendar's jQuery-UI drag needs a real pointer with
  # intermediate moves, and the DB update lands asynchronously after the XHR so Capybara's own
  # waiting doesn't cover it.
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

  def eventually(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return true if yield
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep(0.1)
    end
  end
end
