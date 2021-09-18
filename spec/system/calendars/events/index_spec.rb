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
    let!(:meals_calendar) { create(:community_meals_calendar, name: "Meals") }
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
      create(:event, calendar: calendar2, starts_at: time + 1.hour, ends_at: time + 2.hours,
                     name: "Cal2 Event")
    end

    before do
      meal.build_events
      meal.save!
    end

    scenario "single calendar page" do
      visit(calendar_events_path(calendar1))
      expect(page).to have_content("Yum")
      expect(page).to have_content("Cal1 Event")
      expect(page).to have_css(".fc-agendaWeek-button.fc-state-active") # week view is default
      find(".fc-next-button").click
      find(".fc-next-button").click
      expect(page).not_to have_content("Cal1 Event")
      find(".fc-month-button").click
      expect(page).to have_css(".fc-month-button.fc-state-active")
      sleep(1) # Wait for lens to be updated

      # Test permalink and calendar links update correctly.
      expect_correct_permalink(cur_calendar_id: calendar1.id)

      # Test saved view respected across calendars.
      click_link("Bar Room")
      expect(page).to have_css(".fc-month-button.fc-state-active")
      expect(page).to have_css(".fc-header-toolbar h2", text: time2_my)

      # Test saved view respected on back button click.
      find(".fc-agendaWeek-button").click
      sleep(1) # Wait for lens to be updated
      page.evaluate_script("window.history.back()")
      expect(page).to have_title("Foo Room")
      expect(page).to have_css(".fc-agendaWeek-button.fc-state-active")
    end

    scenario "meal link works" do
      visit(calendar_events_path(meals_calendar))
      click_on("Yum")
      expect(page).to have_title("Yum")
    end

    describe "all events page" do
      let!(:community2) { create(:community) }

      scenario "permalink" do
        visit(calendars_events_path)
        expect(page).to have_title("Events & Reservations")
        find(".fc-next-button").click
        find(".fc-next-button").click
        find(".fc-month-button").click
        expect_correct_permalink(cur_calendar_id: nil)
      end

      scenario "checkboxes, selection load and save" do
        visit(calendars_events_path)
        expect_selected(cal1: true, cal2: false) # Cal 1 sel'd by default

        select_calendar(calendar1, false)
        expect_selected(cal1: false, cal2: false)

        select_calendar(calendar2, true)
        expect_selected(cal1: false, cal2: true)

        visit(calendar_events_path(calendar1)) # Leave page
        expect(page).to have_title("Foo Room")

        visit(calendars_events_path) # Return, saved selection reloaded
        expect_selected(cal1: false, cal2: true)
      end

      scenario "community lens" do
        visit(calendars_events_path)
        expect(page).to have_echoed_url(%r{https?://#{Defaults.community.subdomain}\.})
        select_lens(:community, community2.name)
        expect(page).to have_echoed_url(%r{https?://#{community2.subdomain}\.})
      end
    end

    context "with default calendar view" do
      let!(:calendar3) { create(:calendar, name: "Baz Room", default_calendar_view: "month") }

      scenario "default calendar view is respected unless overridden" do
        visit(calendar_events_path(calendar3))
        expect(page).to have_css(".fc-month-button.fc-state-active")
        find(".fc-agendaWeek-button").click
        sleep(1) # Wait for lens to be updated
        click_link("Events")
        click_link("Baz Room")
        expect(page).to have_title("Baz Room")
        expect(page).to have_css(".fc-agendaWeek-button.fc-state-active")
      end
    end

    def expect_selected(cal1:, cal2:)
      expect(page).send(cal1 ? :to : :not_to, have_content("Cal1 Event"))
      expect(page).send(cal2 ? :to : :not_to, have_content("Cal2 Event"))
      expect(page).send(cal1 ? :to : :not_to, have_css(checkbox_selector(calendar1, checked: true)))
      expect(page).send(cal2 ? :to : :not_to, have_css(checkbox_selector(calendar2, checked: true)))
    end

    def expect_correct_permalink(cur_calendar_id:)
      path = cur_calendar_id ? "/calendars/#{cur_calendar_id}/events" : "/calendars/events"
      permalink_url = "#{path}?view=month&date=#{time2_ymd}"
      expect(page).to have_css(%(a#permalink[href="#{permalink_url}"]))
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
