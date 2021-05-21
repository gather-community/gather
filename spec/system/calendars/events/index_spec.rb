# frozen_string_literal: true

require "rails_helper"

describe "event calendar", js: true do
  let(:actor) { create(:user) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with a meal event and a non-meal event" do
    let!(:calendar1) { create(:calendar, name: "Foo Room") }
    let!(:calendar2) { create(:calendar, name: "Bar Room") }
    let(:time) { Time.current.midnight + 9.hours }

    # This is the start of the month that should be showing on the calendar after two clicks on
    # 'next week' and one click on 'month view'.
    let(:time2) { (Time.current.end_of_week(:sunday) + 1.day + 1.week).at_beginning_of_month }
    let(:time2_ymd) { time2.strftime("%Y-%m-%d") }
    let(:time2_my) { time2.strftime("%B %Y") }

    let!(:meal) { create(:meal, :with_menu, title: "Yum", served_at: time + 9.hours, calendars: [calendar1]) }
    let!(:event) do
      create(:event, calendar: calendar1, starts_at: time, ends_at: time + 1.hour, name: "Funtimes")
    end

    before do
      meal.build_events
      meal.save!
    end

    scenario do
      # Clear saved calendar settings in localStorage
      visit("/")
      page.execute_script("localStorage.clear()")

      visit(calendars_events_path(calendar_id: calendar1.id))
      expect(page).to have_content("Yum")
      expect(page).to have_content("Funtimes")
      find(".fc-next-button").click
      find(".fc-next-button").click
      expect(page).not_to have_content("Funtimes")
      find(".fc-month-button").click

      # Test permalink and calendar links update correctly.
      permalink_url = "/calendars/events?calendar_id=#{calendar1.id}&view=month&date=#{time2_ymd}"
      expect(page).to have_css(%(a#permalink[href="#{permalink_url}"]))
      other_calendar_url = "/calendars/events?calendar_id=#{calendar2.id}&view=month&date=#{time2_ymd}"
      expect(page).to have_css(%(a.calendar-link[href="#{other_calendar_url}"]), text: "Bar Room")

      # Test params respected on page load.
      click_link("Bar Room")
      expect(page).to have_echoed_url(other_calendar_url)
      expect(page).to have_css(".fc-month-button.fc-state-active")
      expect(page).to have_css(".fc-header-toolbar h2", text: time2_my)

      # Test storage of calendar params in localStorage
      visit(calendars_events_path(calendar_id: calendar2.id))
      expect(page).to have_css(".fc-month-button.fc-state-active")
      expect(page).to have_css(".fc-header-toolbar h2", text: time2_my)
    end
  end

  describe "new event flow" do
    let!(:calendar1) { create(:calendar, name: "Foo Room") }
    let!(:calendar2) { create(:calendar, name: "Bar Room") }

    scenario "via combined view and create event button" do
      visit(calendars_events_path)
      click_on("Create Event")
      click_link("Bar Room")
      expect(page).to have_title("Bar Room: Create Event")
    end

    scenario "via combined view and click grid" do
      visit(calendars_events_path)
      all('tr[data-time="11:30:00"] td.fc-widget-content')[-1].click
      expect(page).to have_content(/Create event on.+11:30 am to 12:00 pm/)
      click_on("OK")
      click_link("Bar Room")
      expect(page).to have_title("Bar Room: Create Event")
      expect(page).to have_field("Start Time", with: /11:30/)
    end

    scenario "via single calendar view" do
      visit(calendars_events_path(calendar_id: calendar1.id))
      click_on("Create Event")
      expect(page).to have_title("Foo Room: Create Event")
    end
  end
end
