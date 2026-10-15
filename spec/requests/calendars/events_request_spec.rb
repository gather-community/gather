# frozen_string_literal: true

require "rails_helper"

describe "calendar events JSON endpoint" do
  let(:community) { create(:community) }
  let!(:user) { create(:user, community: community) }
  let!(:calendar) { create(:calendar, community: community, allow_overlap: true) }
  let(:range_start) { "2026-06-15T00:00:00" }
  let(:range_end) { "2026-06-22T00:00:00" }

  before do
    use_user_subdomain(user)
    sign_in(user)
  end

  def fetch_events
    get("/calendars/events", params: {
      start: range_start,
      end: range_end,
      calendar_ids: calendar.id.to_s
    }, xhr: true)
    JSON.parse(response.body)
  end

  context "with a regular non-recurring event in range" do
    let!(:event) do
      create(:event, calendar: calendar, creator: user,
        starts_at: "2026-06-18 10:00", ends_at: "2026-06-18 11:00")
    end

    it "returns correctly shaped JSON" do
      data = fetch_events
      expect(data.size).to eq(1)
      entry = data.first
      expect(entry["title"]).to eq(event.name)
      expect(entry["start"]).to eq("2026-06-18T10:00:00")
      expect(entry["end"]).to eq("2026-06-18T11:00:00")
      expect(entry["calendarId"]).to eq(calendar.id)
      expect(entry["url"]).to include("/calendars/eventlets/#{event.eventlets.first.id}")
      expect(entry).to have_key("editable")
      expect(entry).to have_key("backgroundColor")
    end
  end

  context "with a recurring event whose occurrence falls in range" do
    # Anchor is one week before range start; daily recurrence puts an occurrence on Jun 15.
    let!(:event) do
      create(:event, calendar: calendar, creator: user,
        starts_at: "2026-06-08 14:00", ends_at: "2026-06-08 15:00",
        recurrence_rule: IceCube::Rule.weekly.to_hash)
    end

    it "returns one entry per occurrence with correctly shaped JSON" do
      data = fetch_events
      expect(data.size).to eq(1)
      entry = data.first
      expect(entry["title"]).to eq(event.name)
      expect(entry["start"]).to eq("2026-06-15T14:00:00")
      expect(entry["end"]).to eq("2026-06-15T15:00:00")
      expect(entry["calendarId"]).to eq(calendar.id)
      expect(entry["url"]).to include("/calendars/eventlets/#{event.eventlets.first.id}?occurrence=")
      expect(entry).to have_key("editable")
      expect(entry).to have_key("backgroundColor")
    end

    it "does not return the underlying eventlet for the recurring event" do
      data = fetch_events
      # All returned entries must use the occurrence start time, not the anchor date.
      data.each do |entry|
        expect(entry["start"]).not_to include("2026-06-08")
      end
    end
  end

  context "with a work shift on the Your Jobs system calendar" do
    # Shift show pages are period-scoped, so the feed can't build their URLs polymorphically.
    let!(:calendar) { create(:your_jobs_calendar, community: community) }
    let(:period) do
      create(:work_period, community: community, phase: "open",
        starts_on: "2026-06-01", ends_on: "2026-06-30")
    end
    let(:shift) do
      create(:work_job, period: period, shift_starts: ["2026-06-18 10:00"],
        shift_ends: ["2026-06-18 12:00"]).shifts.first
    end
    let!(:assignment) { create(:work_assignment, shift: shift, user: user) }

    it "returns the period-scoped shift URL" do
      data = fetch_events
      expect(data.size).to eq(1)
      expect(data.first["url"]).to eq("/work/#{period.slug}/signups/#{shift.id}")
    end
  end

  context "with a recurring event whose series ended before the range" do
    let!(:event) do
      create(:event, calendar: calendar, creator: user,
        starts_at: "2026-06-01 10:00", ends_at: "2026-06-01 11:00",
        recurrence_rule: IceCube::Rule.weekly.until(Date.new(2026, 6, 7)).to_hash)
    end

    it "returns no entries" do
      expect(fetch_events).to be_empty
    end
  end
end

# Editing a repeating event works from the occurrence it was opened from. See Calendars::EventForm.
describe "calendar event edit page for a repeating event" do
  let(:community) { create(:community) }
  let!(:user) { create(:user, community: community) }
  let!(:calendar) { create(:calendar, community: community, allow_overlap: true) }
  let(:start) { Time.zone.now.next_week.midnight + 18.hours }
  let!(:event) do
    create(:event, calendar: calendar, creator: user, name: "Book club", starts_at: start,
      ends_at: start + 1.hour, recurrence_rule: IceCube::Rule.weekly.day(start.wday).to_hash)
  end
  let(:eventlet) { event.eventlets.first }
  let(:occurrence) { start + 2.weeks }

  before do
    use_user_subdomain(user)
    sign_in(user)
  end

  it "links from an occurrence's page to editing from that occurrence" do
    get(calendars_eventlet_path(eventlet, occurrence: occurrence.to_i))
    edit_path = edit_calendars_event_path(event, occurrence: occurrence.to_i)
    expect(response.body).to include(edit_path.gsub("&", "&amp;"))
  end

  it "shows the occurrence's times, and a note that changes apply from it on" do
    get(edit_calendars_event_path(event, occurrence: occurrence.to_i))

    expect(response).to have_http_status(:ok)
    page = Capybara.string(response.body)
    # The opened occurrence's date, not the series' first. (The picker pads the hour with a space.)
    expect(page.find_field("calendars_event[starts_at]").value.squish)
      .to eq(I18n.l(occurrence, format: "%a %b %d %Y %l:%M%P").squish)
    expect(page).to have_field("calendars_event[occurrence_start]", type: :hidden, with: occurrence.to_i.to_s)
    expect(page.find(".alert-info").text.squish)
      .to eq("Any changes made below apply only from #{I18n.l(occurrence.to_date)} onward. " \
             "To affect all future occurrences, edit the #{I18n.l(start.to_date)} occurrence.")
    expect(page).to have_link(I18n.l(start.to_date),
      href: edit_calendars_event_path(event, occurrence: start.to_i))
  end

  it "has no note from the first occurrence, where changes apply to the whole series" do
    get(edit_calendars_event_path(event, occurrence: start.to_i))
    expect(Capybara.string(response.body)).to have_no_css(".alert-info")
  end

  context "from a past occurrence" do
    before { Timecop.freeze(start + 1.day) }
    after { Timecop.return }

    it "disables the whole form, with a note linking to the next occurrence" do
      get(edit_calendars_event_path(event, occurrence: start.to_i))
      page = Capybara.string(response.body)
      expect(page).to have_css("fieldset[disabled] #calendars_event_name")
      expect(page).to have_css("fieldset[disabled] #calendars_event_starts_at")
      expect(page).to have_css("fieldset[disabled] #calendars_event_repeat_frequency")
      expect(page).to have_no_button("Save")
      expect(page.find(".alert-warning").text.squish)
        .to start_with("This occurrence has already begun, so it can't")
      expect(page).to have_link(I18n.l((start + 1.week).to_date))
    end
  end

  it "deletes the way the occurrence page does, asking which occurrences" do
    get(edit_calendars_event_path(event, occurrence: occurrence.to_i))
    page = Capybara.string(response.body)
    expect(page).to have_css("a[data-controller='calendars--eventlet-delete']")
    expect(page).to have_no_css("a[href='#{calendars_event_path(event)}'][data-method='delete']")
  end

  it "saves a change from a later occurrence as a new series from there" do
    patch(calendars_event_path(event), params: {calendars_event: {
      occurrence_start: occurrence.to_i, name: "Reading group",
      starts_at: (occurrence + 1.hour).iso8601, ends_at: (occurrence + 2.hours).iso8601
    }})

    expect(response).to have_http_status(:redirect)
    expect(event.reload.name).to eq("Book club")
    ActsAsTenant.with_tenant(event.cluster) do
      split_off = Calendars::Event.where.not(id: event.id).sole
      expect([split_off.name, split_off.starts_at]).to eq(["Reading group", occurrence + 1.hour])
    end
  end
end

# The form-refresh controller posts the event form here as it changes. See EventsController#form_refresh.
describe "calendar event form refresh" do
  let(:community) { create(:community) }
  let!(:user) { create(:user, community: community) }
  let!(:calendar) { create(:calendar, community: community, allow_overlap: true) }
  # The fourth Monday of February 2027, which is also the last. Mondays in March 2027 are the 1st, 8th,
  # 15th, 22nd and 29th.
  let(:fourth_monday) { Time.zone.local(2027, 2, 22, 18) }
  let(:fifth_monday) { Time.zone.local(2027, 3, 29, 18) }

  before do
    use_user_subdomain(user)
    sign_in(user)
  end

  def refresh(path, starts_at, **params)
    post(path, headers: {"Accept" => "text/vnd.turbo-stream.html"}, params: {calendars_event: {
      starts_at: starts_at.iso8601, ends_at: (starts_at + 1.hour).iso8601, repeat_frequency: "monthly",
      repeat_monthly_by: "day_of_week", **params
    }})
  end

  def monthly_choices
    stream = Capybara.string(response.body)
    expect(stream).to have_css("turbo-stream[action='replace'][method='morph']" \
      "[target='calendars_event_repeat_monthly_by_field']", visible: :all)
    template = Capybara.string(response.body[%r{<template>(.*)</template>}m, 1])
    select = template.find("select#calendars_event_repeat_monthly_by", visible: :all)
    [select.all("option", visible: :all).map(&:text), select.find("option[selected]", visible: :all).value]
  end

  it "words the monthly choices from a new event's start, offering both the 4th and the last" do
    refresh(form_refresh_calendars_events_path, fourth_monday, calendar_id: calendar.id)
    expect(response).to have_http_status(:ok)
    expect(monthly_choices).to eq([["Day 22", "The fourth Monday", "The last Monday"], "day_of_week"])
  end

  it "switches to the last when the start moves to a fifth weekday" do
    refresh(form_refresh_calendars_events_path, fifth_monday, calendar_id: calendar.id)
    expect(monthly_choices).to eq([["Day 29", "The last Monday"], "last_day_of_week"])
  end

  it "words them from the form's times when editing a series from an occurrence" do
    # On the 1st of each month, opened from March 1st and moved to the 29th.
    first = Time.zone.local(2027, 1, 1, 18)
    event = create(:event, calendar: calendar, creator: user, starts_at: first, ends_at: first + 1.hour,
      recurrence_rule: IceCube::Rule.monthly.day_of_month(1).to_hash)
    refresh(form_refresh_calendars_event_path(event), fifth_monday,
      occurrence_start: Time.zone.local(2027, 3, 1, 18).to_i, repeat_monthly_by: "day_of_month")
    expect(monthly_choices).to eq([["Day 29", "The last Monday"], "day_of_month"])
    expect(event.reload.starts_at).to eq(first)
  end

  it "saves nothing" do
    expect { refresh(form_refresh_calendars_events_path, fourth_monday, calendar_id: calendar.id, name: "X") }
      .not_to change { ActsAsTenant.with_tenant(calendar.cluster) { Calendars::Event.count } }
  end

  it "is refused for someone who can't edit the event" do
    event = create(:event, calendar: calendar, starts_at: fourth_monday, ends_at: fourth_monday + 1.hour)
    expect { refresh(form_refresh_calendars_event_path(event), fourth_monday) }
      .to raise_error(Pundit::NotAuthorizedError)
  end
end
