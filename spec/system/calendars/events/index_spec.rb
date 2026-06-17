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

      expect_correct_permalink(cur_calendar_id: calendar1.id)

      # Sidebar calendar links carry the current view and date.
      click_link("Bar Room")
      expect(page).to have_css(".fc-month-button.fc-state-active")
      expect(page).to have_css(".fc-header-toolbar h2", text: time2_my)

      # Second link click — view and date still carry through from the URL.
      click_link("Foo Room")
      expect(page).to have_css(".fc-month-button.fc-state-active")
      expect(page).to have_css(".fc-header-toolbar h2", text: time2_my)
    end

    scenario "All link navigates to combined events page and carries view/date" do
      visit(calendar_events_path(calendar1))
      expect(page).to have_css(".fc-agendaWeek-button.fc-state-active")
      find(".fc-next-button").click
      find(".fc-month-button").click
      expect(page).to have_css(".fc-month-button.fc-state-active")

      # The All link gets QS params rewritten just like per-calendar links.
      all_href = find("a.calendar-link", text: "All")["href"]
      expect(all_href).to match(%r{/calendars/events})
      expect(all_href).to match(/[?&]view=month/)
      expect(all_href).to match(/[?&]date=\d{4}-\d{2}-\d{2}/)

      # Clicking it lands on the combined events page at the same position.
      click_link("All")
      expect(page).to have_title("Events & Reservations")
      expect(page).to have_css(".fc-month-button.fc-state-active")
    end

    scenario "meal link works" do
      visit(calendar_events_path(meals_calendar))
      click_on("Yum")
      expect(page).to have_title("Yum")
    end

    scenario "sidebar links stay clean on load (no date or view until user navigates)" do
      visit(calendar_events_path(calendar1))
      expect(page).to have_css(".fc-agendaWeek-button.fc-state-active")
      link_href = find("a", text: "Bar Room")["href"]
      expect(link_href).not_to match(/[?&]date=/)
      expect(link_href).not_to match(/[?&]view=/)
    end

    scenario "URL stays clean on load; date appears after navigation, view only after view change" do
      visit(calendar_events_path(calendar1))
      expect(page).to have_css(".fc-agendaWeek-button.fc-state-active") # calendar fully loaded
      expect(current_url).not_to match(/[?&]view=/)
      expect(current_url).not_to match(/[?&]date=/)

      find(".fc-next-button").click
      expect(page).to have_current_path(/[?&]date=\d{4}-\d{2}-\d{2}/)
      expect(current_url).not_to match(/[?&]view=/) # view not added by next/prev

      find(".fc-month-button").click
      expect(page).to have_current_path(/[?&]view=month/)
      expect(page).to have_current_path(/[?&]date=\d{4}-\d{2}-\d{2}/)

      find(".fc-next-button").click
      expect(page).to have_current_path(/[?&]view=month/) # view persists after subsequent navigation
    end

    scenario "view param in URL on load carries through to sidebar links without any navigation" do
      # Loading with a permalink-style URL and clicking a sidebar link directly (no next/prev).
      visit(calendar_events_path(calendar1, view: "month", date: time2_ymd))
      expect(page).to have_css(".fc-month-button.fc-state-active")
      click_link("Bar Room")
      expect(page).to have_css(".fc-month-button.fc-state-active")
      expect(page).to have_css(".fc-header-toolbar h2", text: time2_my)

      # Second link click — view and date still carry via the URL params on the destination page.
      click_link("Foo Room")
      expect(page).to have_css(".fc-month-button.fc-state-active")
      expect(page).to have_css(".fc-header-toolbar h2", text: time2_my)
    end

    scenario "early morning toggle updates URL and carries through sidebar links" do
      visit(calendar_events_path(calendar1))
      expect(page).to have_css(".fc-agendaWeek-button.fc-state-active")

      find("#show-early").click
      expect(page).to have_current_path(/[?&]early=true/)

      # Toggling off removes the param.
      find("#hide-early").click
      expect(current_url).not_to match(/[?&]early=/)

      # Sidebar links carry the early param to the destination calendar.
      find("#show-early").click
      expect(page).to have_current_path(/[?&]early=true/)
      click_link("Bar Room")
      expect(page).to have_css(".fc-agendaWeek-button.fc-state-active") # calendar loaded
      expect(current_url).to match(/[?&]early=true/)
      expect(page).to have_css("#hide-early", visible: true) # early morning is active
    end

    scenario "back button restores previous calendar position" do
      visit(calendar_events_path(calendar1))
      expect(page).to have_content("Cal1 Event") # event is on current week

      find(".fc-next-button").click
      expect(page).to have_current_path(/[?&]date=\d{4}-\d{2}-\d{2}/)
      expect(page).not_to have_content("Cal1 Event") # navigated away from event's week

      page.evaluate_script("window.history.back()")
      expect(page).to have_content("Cal1 Event") # calendar returned to event's week
    end

    describe "all events page" do
      let!(:community2) { create(:community) }

      scenario "URL stays clean on load; date appears after navigation, view only after view change" do
        visit(calendars_events_path)
        expect(page).to have_css(".fc-agendaWeek-button.fc-state-active")
        expect(current_url).not_to match(/[?&]view=/)
        expect(current_url).not_to match(/[?&]date=/)

        find(".fc-next-button").click
        expect(page).to have_current_path(/[?&]date=\d{4}-\d{2}-\d{2}/)
        expect(current_url).not_to match(/[?&]view=/) # view not added by next/prev

        find(".fc-month-button").click
        expect(page).to have_current_path(/[?&]view=month/)
        expect(page).to have_current_path(/[?&]date=\d{4}-\d{2}-\d{2}/)
      end

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

        uncheck("Foo Room")
        expect_selected(cal1: false, cal2: false)

        check("Bar Room")
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

      scenario "default calendar view is always used on load" do
        visit(calendar_events_path(calendar3))
        expect(page).to have_css(".fc-month-button.fc-state-active")
        find(".fc-agendaWeek-button").click
        click_link("Events")
        click_link("Baz Room")
        expect(page).to have_title("Baz Room")
        expect(page).to have_css(".fc-month-button.fc-state-active")
      end

      scenario "a previous visit with a view param does not override default_calendar_view" do
        # Visiting with ?view=week stores the value in the lens session.
        visit(calendar_events_path(calendar3, view: "week"))
        expect(page).to have_css(".fc-agendaWeek-button.fc-state-active")

        # A subsequent clean load must use default_calendar_view, not the stale session value.
        visit(calendar_events_path(calendar3))
        expect(page).to have_css(".fc-month-button.fc-state-active")
      end
    end
  end

  describe "all day events row" do
    let(:calendar) { create(:calendar) }

    context "with a calendar that supports them" do
      scenario do
        visit(calendar_events_path(calendar))
        expect(page).to have_content("All Day")

        find(".fc-day-grid td[data-date=\"#{Time.current.to_fs(:no_time)}\"]").click
        expect(page).to have_content(/Create event on #{I18n.l(Time.current, format: :wday_no_year_no_time)}/)
      end
    end

    context "with a calendar that doesn't support them" do
      let!(:protocol) { create(:calendar_protocol, calendars: [calendar], fixed_start_time: "8:00am") }

      scenario do
        visit(calendar_events_path(calendar))
        expect(page).not_to have_content("All Day")
      end
    end
  end

  describe "calendar view switching" do
    let(:calendar) { create(:calendar) }

    scenario "renders week, day, and month grids after keyboard view changes" do
      visit(calendar_events_path(calendar))

      expect(page).to have_css(".fc-agendaWeek-view .fc-time-grid")
      find(".fc-agendaWeek-button").send_keys(:enter)
      expect_active_gridcell(".fc-agendaWeek-view .fc-day[data-date][tabindex='0']")

      find(".fc-agendaDay-button").send_keys(:enter)
      expect(page).to have_css(".fc-agendaDay-view .fc-time-grid")
      expect_active_gridcell(".fc-agendaDay-view .fc-day[data-date][tabindex='0']")

      find(".fc-month-button").send_keys(:enter)
      expect(page).to have_css(".fc-month-view .fc-bg .fc-day[data-date]")
      expect_active_gridcell(".fc-month-view .fc-day[data-date][tabindex='0']")

      find(".fc-agendaWeek-button").send_keys(:enter)
      expect(page).to have_css(".fc-agendaWeek-view .fc-time-grid")
      expect_active_gridcell(".fc-agendaWeek-view .fc-day[data-date][tabindex='0']")
    end
  end

  describe "calendar grid accessibility states" do
    let(:calendar) { create(:calendar) }

    scenario "exposes selected, active, and today states on date cells" do
      visit(calendar_events_path(calendar))
      find(".fc-month-button").click

      today = Time.zone.today
      today_date = today.to_fs(:no_time)
      today_label = page.evaluate_script("moment('#{today_date}', 'YYYY-MM-DD').format('dddd, MMMM D, YYYY')")
      selected_cell_selector =
        ".fc-month-view .fc-day[data-date][tabindex='0'][aria-selected='true']"

      expect(page).to have_css(".fc-month-view .fc-day[data-date='#{today_date}'][aria-current='date']")
      expect(page).to have_css(
        ".fc-month-view .fc-day[data-date='#{today_date}'][aria-label='#{today_label}']"
      )
      expect(page).to have_css(selected_cell_selector, count: 1)

      selected_date_before_click = find(selected_cell_selector)["data-date"]
      target_date = page.evaluate_script(<<~JS)
        (() => {
          const cells = Array.from(document.querySelectorAll(".fc-month-view .fc-day[data-date]"))
            .filter(cell => cell.offsetParent !== null);
          const selectedIndex = cells.findIndex(cell => cell.getAttribute("aria-selected") === "true");
          const selectedDate = cells[selectedIndex].getAttribute("data-date");
          const target = cells.find((cell, index) => {
            return index > selectedIndex && cell.getAttribute("data-date") !== selectedDate;
          }) || cells.find((cell) => cell.getAttribute("data-date") !== selectedDate);

          return target && target.getAttribute("data-date");
        })()
      JS
      expect(target_date).not_to eq(selected_date_before_click)
      find(selected_cell_selector).send_keys(:arrow_right)

      expect(page).to have_no_css(
        ".fc-month-view .fc-day[data-date='#{selected_date_before_click}'][aria-selected='true']"
      )
      expect(page).to have_css(".fc-month-view .fc-day[data-date='#{target_date}'][aria-selected='true']")
      expect(page).to have_css(
        ".fc-month-view .fc-day[data-date][tabindex='0'][aria-selected='true'].fc-gather-grid-active",
        count: 1
      )
      expect(page).to have_css(".fc-month-view .fc-day[data-date='#{today_date}'][aria-current='date']")
      expect(page).to have_css(".fc-month-view .fc-day[data-date][aria-selected='true']", count: 1)

      next_month_date = today.next_month.beginning_of_month.to_fs(:no_time)
      page.execute_script("$('#calendar').fullCalendar('next')")
      expect(page).to have_css(".fc-month-view .fc-day[data-date='#{next_month_date}'][aria-label]")
      expect(page).to have_css(".fc-month-view .fc-day[data-date][aria-label]", minimum: 1)
      rerendered_cell = page.evaluate_script(<<~JS)
        (() => {
          const cell = document.querySelector(".fc-month-view .fc-day[data-date='#{next_month_date}']");
          const date = cell.getAttribute("data-date");

          return {
            date,
            label: cell.getAttribute("aria-label"),
            expectedLabel: moment(date, "YYYY-MM-DD").format("dddd, MMMM D, YYYY")
          };
        })()
      JS
      expect(rerendered_cell["label"]).to eq(rerendered_cell["expectedLabel"])
    end
  end

  def expect_selected(cal1:, cal2:)
    expect(page).send(cal1 ? :to : :not_to, have_content("Cal1 Event"))
    expect(page).send(cal2 ? :to : :not_to, have_content("Cal2 Event"))
    expect(page).to have_field("Foo Room", checked: cal1)
    expect(page).to have_field("Bar Room", checked: cal2)
  end

  def expect_correct_permalink(cur_calendar_id:)
    path = cur_calendar_id ? "/calendars/#{cur_calendar_id}/events" : "/calendars/events"
    permalink_url = "#{path}?view=month&date=#{time2_ymd}"
    expect(page).to have_css(%(a#permalink[href="#{permalink_url}"]))
  end

  def expect_active_gridcell(selector)
    expect(page).to have_css(selector)
    expect(page.evaluate_script("document.activeElement.matches(#{selector.to_json})")).to be(true)
  end
end
