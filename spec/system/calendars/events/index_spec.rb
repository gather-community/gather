# frozen_string_literal: true

require "rails_helper"

describe "event calendar", js: true do
  let(:actor) { create(:user) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with a meal event and a non-meal event" do
    let!(:calendar1) { create(:calendar, name: "Foo Room", selected_by_default: true) }
    let!(:calendar2) { create(:calendar, name: "Bar Room") }
    let(:time) { Time.current.midnight + 9.hours }

    # This is the start of the month that should be showing on the calendar after two clicks on
    # 'next week' and one click on 'month view'.
    let(:time2) { (Time.current.end_of_week(:sunday) + 1.day + 1.week).at_beginning_of_month }
    let(:time2_ymd) { time2.strftime("%Y-%m-%d") }
    let(:time2_my) { time2.strftime("%B %Y") }

    let!(:meal) { create(:meal, :with_menu, title: "Yum", served_at: time + 9.hours, calendars: [calendar1]) }
    let!(:event1) do
      create(:event, calendar: calendar1, starts_at: time, ends_at: time + 1.hour, name: "Cal1 Event")
    end
    let!(:event2) do
      create(:event, calendar: calendar2, starts_at: time + 1.hour, ends_at: time + 2.hours, name: "Cal2 Event")
    end

    before do
      meal.build_events
      meal.save!
    end

    scenario "single calendar page" do
      # Clear saved calendar settings in localStorage
      visit("/")
      page.execute_script("localStorage.clear()")

      visit(calendars_events_path(calendar_id: calendar1.id))
      expect(page).to have_content("Yum")
      expect(page).to have_content("Cal1 Event")
      find(".fc-next-button").click
      find(".fc-next-button").click
      expect(page).not_to have_content("Cal1 Event")
      find(".fc-month-button").click

      # Test permalink and calendar links update correctly.
      expect_correct_permalink_and_other_calendar_link(cur_calendar_id: calendar1.id)

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

    describe "all events page" do
      scenario "permalink" do
        visit(calendars_events_path)
        expect(page).to have_title("Events & Reservations")
        find(".fc-next-button").click
        find(".fc-next-button").click
        find(".fc-month-button").click
        expect_correct_permalink_and_other_calendar_link(cur_calendar_id: nil)
      end

      scenario "checkboxes, selection save & reset" do
        visit(calendars_events_path)
        expect_selected(cal1: true, cal2: false) # Cal 1 sel'd by default

        select_calendar(calendar1, false)
        expect_selected(cal1: false, cal2: false)

        select_calendar(calendar2, true)
        expect_selected(cal1: false, cal2: true)

        click_link("Reset Selection") # Resetting selection goes back to defaults since nothing saved yet.
        expect_selected(cal1: true, cal2: false)

        select_calendar(calendar1, false)
        select_calendar(calendar2, true)
        expect_selected(cal1: false, cal2: true)

        click_link("Save Selection")

        select_calendar(calendar1, true)
        expect_selected(cal1: true, cal2: true)

        visit(calendars_events_path) # Saved selection reloaded
        expect_selected(cal1: false, cal2: true)

        select_calendar(calendar1, true)
        expect_selected(cal1: true, cal2: true)

        click_link("Reset Selection") # Resetting selection now goes back to saved one
        expect_selected(cal1: false, cal2: true)
      end
    end

    def expect_selected(cal1:, cal2:)
      expect(page).send(cal1 ? :to : :not_to, have_content("Cal1 Event"))
      expect(page).send(cal2 ? :to : :not_to, have_content("Cal2 Event"))
      expect(page).send(cal1 ? :to : :not_to, have_css(checkbox_selector(calendar1, checked: true)))
      expect(page).send(cal2 ? :to : :not_to, have_css(checkbox_selector(calendar2, checked: true)))
    end

    def expect_correct_permalink_and_other_calendar_link(cur_calendar_id:)
      cur_calendar_param = cur_calendar_id ? "calendar_id=#{cur_calendar_id}&" : ""
      permalink_url = "/calendars/events?#{cur_calendar_param}view=month&date=#{time2_ymd}"
      expect(page).to have_css(%(a#permalink[href="#{permalink_url}"]))
      expect(page).to have_css(%(a.calendar-link[href="#{other_calendar_url}"]), text: "Bar Room")
    end

    def other_calendar_url
      "/calendars/events?calendar_id=#{calendar2.id}&view=month&date=#{time2_ymd}"
    end

    def select_calendar(calendar, select)
      el = first(checkbox_selector(calendar))
      select ? el.check : el.uncheck
    end

    def checkbox_selector(calendar, checked: false)
      "input[type='checkbox'][value='#{calendar.id}']#{checked ? ':checked' : ''}"
    end
  end
end
