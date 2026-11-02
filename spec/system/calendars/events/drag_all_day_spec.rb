# frozen_string_literal: true

require "rails_helper"

# Drags involving the all-day row and month view. A drag can't move an event between the all-day
# row and the time grid (CalendarView#eventAllow), since the server keeps an event's all-day setting
# as it is; that's changed in the event form instead.
describe "dragging all-day events and in month view", js: true do
  let(:actor) { create(:user) }
  # Overlap is allowed so the two events here can share a day; blocking overlaps is in drag_spec.rb.
  let(:calendar) { create(:calendar, selected_by_default: true, allow_overlap: true) }

  # A Wednesday in next week's Sunday-based view (see drag_spec.rb for why Sunday-based).
  let(:day) { (Time.current.beginning_of_week(:sunday) + 1.week + 3.days).to_date }
  let(:timed_start) { day.in_time_zone + 12.hours }

  let!(:timed) do
    create(:event, calendar: calendar, creator: actor, name: "Timed",
      starts_at: timed_start, ends_at: timed_start + 1.hour)
  end
  let!(:all_day) do
    create(:event, calendar: calendar, creator: actor, name: "AllDay", all_day: true,
      starts_at: (day + 1).in_time_zone, ends_at: (day + 1).in_time_zone)
  end

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
    visit(calendar_events_path(calendar))
    find(".fc-next-button").click
    expect(page).to have_css(".fc-event", text: "AllDay")
  end

  def event_el(name)
    find(".fc-event", text: name)
  end

  def all_day_cell(date)
    find(".fc-day-grid .fc-day[data-date='#{date.iso8601}']")
  end

  def expect_unchanged(event, starts_at, ends_at, all_day:)
    sleep(1)
    expect(page).not_to have_css(modal_selector)
    event.reload
    expect(event.starts_at).to be_within(1.second).of(starts_at)
    expect(event.ends_at).to be_within(1.second).of(ends_at)
    expect(event.all_day).to be(all_day)
  end

  scenario "an all-day event dragged to another day stays all-day" do
    drag_horizontally(event_el("AllDay"), columns: 1)
    click_modal_button

    expect(eventually { all_day.reload.starts_at.to_date == day + 2 })
      .to be(true), "Expected the event to move to #{day + 2}, but it starts #{all_day.reload.starts_at}"
    expect(all_day).to be_all_day
    expect(all_day.ends_at.to_date).to eq(day + 2)
  end

  scenario "an all-day event stretched over more days" do
    resize_horizontally(event_el("AllDay"), columns: 2)
    click_modal_button

    expect(eventually { all_day.reload.ends_at.to_date == day + 3 })
      .to be(true), "Expected the event to end on #{day + 3}, but it ends #{all_day.reload.ends_at}"
    expect(all_day.starts_at.to_date).to eq(day + 1)
    expect(all_day).to be_all_day
  end

  scenario "a timed event can't be dropped into the all-day row" do
    drag_onto(event_el("Timed"), all_day_cell(day))
    expect_unchanged(timed, timed_start, timed_start + 1.hour, all_day: false)
  end

  scenario "an all-day event can't be dropped into the time grid" do
    drag_vertically(event_el("AllDay"), by: 250)
    expect_unchanged(all_day, (day + 1).in_time_zone, (day + 1).in_time_zone.end_of_day, all_day: true)
  end

  context "in month view" do
    before do
      find(".fc-month-button").click
      expect(page).to have_css(".fc-month-view .fc-event", text: "Timed")
    end

    scenario "a timed event dragged to another day keeps its time" do
      drag_horizontally(event_el("Timed"), columns: 1)
      click_modal_button

      expect(eventually { timed.reload.starts_at.to_date == day + 1 })
        .to be(true), "Expected the event to move to #{day + 1}, but it starts #{timed.reload.starts_at}"
      expect(timed.starts_at).to be_within(1.second).of(timed_start + 1.day)
      expect(timed.ends_at).to be_within(1.second).of(timed_start + 1.day + 1.hour)
    end

    scenario "an all-day event dragged to another day stays all-day" do
      drag_horizontally(event_el("AllDay"), columns: 1)
      click_modal_button

      expect(eventually { all_day.reload.starts_at.to_date == day + 2 })
        .to be(true), "Expected the event to move to #{day + 2}, but it starts #{all_day.reload.starts_at}"
      expect(all_day).to be_all_day
    end
  end
end
