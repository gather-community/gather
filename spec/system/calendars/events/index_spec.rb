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

    scenario "sidebar calendar list is exposed as a labeled landmark", js: false do
      calendar_group = create(:calendar_group, name: "Reservations")
      create(:calendar, name: "Study Room", group: calendar_group)

      visit(calendar_events_path(calendar1))
      expect_sidebar_calendar_list_landmark

      visit(calendars_events_path)
      expect_sidebar_calendar_list_landmark
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

    scenario "announces month changes in a live region" do
      visit(calendar_events_path(calendar))
      find(".fc-month-button").click

      expect(page).to have_css(
        "#calendar-live-region[aria-live='polite'][aria-atomic='true']",
        visible: false
      )

      next_month = Time.zone.today.next_month.strftime("%B %Y")
      find(".fc-next-button").click
      expect(page).to have_css(
        "#calendar-live-region",
        text: "Calendar now showing #{next_month}",
        visible: false
      )
    end

    scenario "announces empty week and month views in a live region" do
      visit(calendar_events_path(calendar))

      expect(page).to have_css("#calendar-live-region", text: "No events this week", visible: false)

      find(".fc-agendaDay-button").click
      expect(page).to have_css("#calendar-live-region", text: "", visible: false)

      find(".fc-month-button").click
      expect(page).to have_css("#calendar-live-region", text: "No events this month", visible: false)
    end

    scenario "announces event counts for views and focused day cells" do
      today = Time.zone.today
      create(:event, calendar: calendar, all_day: true, starts_at: today.in_time_zone,
        ends_at: today.in_time_zone + 1.day - 1.second)

      visit(calendar_events_path(calendar))

      week_today_label = expected_date_label(today, prefix: "All Day", count: "1 event")
      month_today_label = expected_date_label(today, count: "1 event")

      expect(page).to have_css("#calendar-live-region", text: "1 event this week", visible: false)
      expect(page).to have_css(
        ".fc-agendaWeek-view .fc-day-grid .fc-bg .fc-day[data-date='#{today.to_fs(:no_time)}']" \
        "[aria-label='#{week_today_label}']"
      )

      find(".fc-month-button").click
      expect(page).to have_css("#calendar-live-region", text: "1 event this month", visible: false)
      expect(page).to have_css(
        ".fc-month-view .fc-bg .fc-day[data-date='#{today.to_fs(:no_time)}']" \
        "[aria-label='#{month_today_label}']"
      )
    end

    scenario "supports keyboard navigation and labels for day and week time slots" do
      visit(calendar_events_path(calendar))

      today = Time.zone.today
      today_date = today.to_fs(:no_time)
      current_week_other_day = today.wday.zero? ? today + 1.day : today - 1.day
      current_week_other_date = current_week_other_day.to_fs(:no_time)
      all_day_selector =
        ".fc-agendaWeek-view .fc-day-grid .fc-bg .fc-day[data-date='#{today_date}']"
      current_week_all_day_selector =
        ".fc-agendaWeek-view .fc-day-grid .fc-bg .fc-day[data-date='#{current_week_other_date}']"
      first_slot_selector =
        ".fc-agendaWeek-view .fc-gather-time-slot[data-date='#{today_date}'][data-time='06:00:00']"
      current_week_slot_selector =
        ".fc-agendaWeek-view .fc-gather-time-slot" \
        "[data-date='#{current_week_other_date}'][data-time='06:00:00']"

      all_day_label = expected_date_label(today, prefix: "All Day", include_week_context: true)
      current_week_all_day_label =
        expected_date_label(current_week_other_day, prefix: "All Day", include_week_context: true)
      first_slot_label = expected_time_slot_label(today, "06:00:00", include_week_context: true)
      current_week_slot_label =
        expected_time_slot_label(current_week_other_day, "06:00:00", include_week_context: true)

      expect(page).to have_css("#{all_day_selector}[aria-label='#{all_day_label}']")
      expect(page).to have_css("#{current_week_all_day_selector}[aria-label='#{current_week_all_day_label}']")
      expect(page).to have_css("#{first_slot_selector}[aria-label='#{first_slot_label}']")
      expect(page).to have_css("#{current_week_slot_selector}[aria-label='#{current_week_slot_label}']")
      week_grid_label = expected_grid_label(".fc-agendaWeek-view", "Week calendar")
      expect(page).to have_css(
        ".fc-agendaWeek-view[role='grid'][aria-label='#{week_grid_label}']"
      )
      expect(page).to have_no_css(".fc-agendaWeek-view .fc-time-grid[role='grid']")
      expect(page).to have_no_css(".fc-agendaWeek-view .fc-time-grid .fc-bg .fc-day[aria-label]")
      expect(page).to have_css("#{first_slot_selector}[aria-hidden='true']")
      expect(page).to have_css(".fc-agendaWeek-view .fc-slats[aria-hidden='true']")

      find("#{all_day_selector}[tabindex='0']").send_keys(:tab)
      tab_target = page.evaluate_script(<<~JS)
        (() => {
          const el = document.activeElement;
          if (!el || el === document.body) {
            return {ok: true, reason: "body"};
          }
          const role = el.getAttribute("role");
          const label = el.getAttribute("aria-label") || el.getAttribute("aria-labelledby");
          const inUnlabeledGrid = role === "grid" && !label;
          const isTimeGridChrome = !!(el.closest && el.closest(".fc-time-grid") &&
            !el.classList.contains("fc-gather-time-slot") && !el.classList.contains("fc-event"));
          return {
            ok: !inUnlabeledGrid && !isTimeGridChrome,
            role,
            label,
            className: el.className,
            id: el.id
          };
        })()
      JS
      expect(tab_target["ok"]).to eq(true),
        "Tab from all-day landed on unlabeled calendar chrome: #{tab_target.inspect}"

      find("#{all_day_selector}[tabindex='0']").send_keys(:arrow_down)
      expect_active_gridcell("#{first_slot_selector}[tabindex='0']")
      expect(page).to have_css(
        "#{first_slot_selector}[role='button']:not([aria-hidden='true'])"
      )
      expect(page).to have_no_css("#{first_slot_selector}[aria-selected]")
      expect(page).to have_no_css("#{first_slot_selector}[aria-describedby]")
      expect(page).to have_css(
        ".fc-agendaWeek-view .fc-gather-time-slot[data-time='06:30:00'][aria-hidden='true']",
        minimum: 1
      )
      expect(page).to have_no_css(
        ".fc-agendaWeek-view .fc-gather-time-slot[aria-selected='false']"
      )

      find(first_slot_selector).send_keys(:arrow_down)
      half_hour_selector =
        ".fc-agendaWeek-view .fc-gather-time-slot[data-date='#{today_date}']" \
        "[data-time='06:30:00']"
      expect_active_gridcell("#{half_hour_selector}[tabindex='0']")
      half_hour_label = expected_time_slot_label(today, "06:30:00", include_week_context: true)
      expect(page).to have_css("#{half_hour_selector}[aria-label='#{half_hour_label}']")

      find(half_hour_selector).send_keys(:arrow_up)
      expect_active_gridcell(
        "#{first_slot_selector}[role='button'][tabindex='0']:not([aria-hidden='true'])"
      )
      expect(page).to have_css("#{half_hour_selector}[aria-hidden='true']:not([role])")

      find(first_slot_selector).send_keys(:arrow_up)
      expect_active_gridcell("#{all_day_selector}[tabindex='0']")

      find("#{all_day_selector}[tabindex='0']").send_keys(:arrow_down)
      move = page.evaluate_script(<<~JS)
        (() => {
          const current = document.querySelector(#{first_slot_selector.to_json});
          const currentDate = current.getAttribute("data-date");
          const slots = Array.from(
            document.querySelectorAll(
              ".fc-agendaWeek-view .fc-gather-time-slot[data-time='06:00:00']"
            )
          );
          const next = slots.find((slot) => slot.getAttribute("data-date") > currentDate);
          if (next) {
            return {date: next.getAttribute("data-date"), key: "ArrowRight"};
          }
          const prev = [...slots].reverse()
            .find((slot) => slot.getAttribute("data-date") < currentDate);
          return prev && {date: prev.getAttribute("data-date"), key: "ArrowLeft"};
        })()
      JS
      expect(move).to be_present
      find(first_slot_selector).send_keys(move["key"] == "ArrowRight" ? :arrow_right : :arrow_left)
      adjacent_slot_selector =
        ".fc-agendaWeek-view .fc-gather-time-slot[data-date='#{move['date']}']" \
        "[data-time='06:00:00']"
      expect_active_gridcell("#{adjacent_slot_selector}[tabindex='0']")

      find(adjacent_slot_selector).send_keys(:enter)
      expect(page).to have_content(/Create event on.+6:00 am to 6:30 am/i)
      expect(page).to have_css(
        "#create-confirm-modal[role='dialog'][aria-modal='true']" \
        "[aria-labelledby='create-confirm-modal-title']"
      )
      expect(page).to have_css("#create-confirm-modal-title", text: "Create Event?")
      expect(page).to have_css("#create-confirm-modal .btn-default:focus", text: "Cancel")
      expect(page).to have_css(".fc-helper-container .fc-event")

      find("#create-confirm-modal .btn-default").send_keys(:escape)
      expect(page).to have_no_css(".modal.in")
      expect(page).to have_no_css(".fc-helper-container .fc-event")
      expect_active_gridcell("#{adjacent_slot_selector}[tabindex='0']")
      find(".fc-today-button").click
      find(".fc-agendaDay-button").click
      expect(page).to have_css(".fc-agendaDay-view .fc-time-grid")

      day_all_day_selector =
        ".fc-agendaDay-view .fc-day-grid .fc-bg .fc-day[data-date='#{today_date}']"
      day_first_slot_selector =
        ".fc-agendaDay-view .fc-gather-time-slot[data-date='#{today_date}'][data-time='06:00:00']"
      day_all_day_label = expected_date_label(today, prefix: "All Day", include_week_context: true)
      day_first_slot_label = expected_time_slot_label(today, "06:00:00", include_week_context: true)

      expect(page).to have_css("#{day_all_day_selector}[aria-label='#{day_all_day_label}']")
      expect(page).to have_css("#{day_first_slot_selector}[aria-label='#{day_first_slot_label}']")
      day_grid_label = expected_grid_label(".fc-agendaDay-view", "Day calendar")
      expect(page).to have_css(".fc-agendaDay-view[role='grid'][aria-label='#{day_grid_label}']")

      find(day_all_day_selector).send_keys(:arrow_down)
      expect_active_gridcell("#{day_first_slot_selector}[tabindex='0']")

      find("#show-early").click
      midnight_slot_selector =
        ".fc-agendaDay-view .fc-gather-time-slot[data-date='#{today_date}'][data-time='00:00:00']"
      expect(page).to have_css(".fc-agendaDay-view .fc-divider[aria-hidden='true']", visible: false)
      page.execute_script("document.querySelector(#{midnight_slot_selector.to_json}).focus()")
      expect_active_gridcell("#{midnight_slot_selector}[role='button'][tabindex='0']")
      expect(page).to have_no_css("#{midnight_slot_selector}[aria-selected]")
      find(midnight_slot_selector).send_keys(:arrow_up)
      expect_active_gridcell("#{day_all_day_selector}[tabindex='0']")
    end

    scenario "preserves the focused time slot when arrow navigation crosses weeks" do
      visit(calendar_events_path(calendar))

      last_date = all(".fc-agendaWeek-view .fc-gather-time-slot[data-time='06:00:00']")
        .last["data-date"]
      first_new_week_date = Date.iso8601(last_date).next_day
      second_new_week_date = first_new_week_date.next_day
      last_slot_selector =
        ".fc-agendaWeek-view .fc-gather-time-slot[data-date='#{last_date}'][data-time='06:00:00']"
      first_new_week_slot_selector =
        ".fc-agendaWeek-view .fc-gather-time-slot" \
        "[data-date='#{first_new_week_date.to_fs(:no_time)}'][data-time='06:00:00']"
      second_new_week_slot_selector =
        ".fc-agendaWeek-view .fc-gather-time-slot" \
        "[data-date='#{second_new_week_date.to_fs(:no_time)}'][data-time='06:00:00']"

      page.execute_script(<<~JS)
        window.calendarFocusedSlot = document.querySelector(#{last_slot_selector.to_json});
        window.calendarFocusedSlot.focus();
      JS
      find(last_slot_selector).send_keys(:arrow_right)

      expect_active_gridcell("#{first_new_week_slot_selector}[tabindex='0']")
      first_new_week_label =
        expected_time_slot_label(first_new_week_date, "06:00:00", include_week_context: true)
      expect(page).to have_css(
        "#{first_new_week_slot_selector}[aria-label='#{first_new_week_label}']"
      )
      expect(page).to have_css(
        "#calendar-grid-focus-live-region[aria-live='assertive'][aria-atomic='true']",
        text: first_new_week_label,
        visible: false
      )
      expect(page.evaluate_script(
        "window.calendarFocusedSlot === document.activeElement"
      )).to eq(true)

      find(first_new_week_slot_selector).send_keys(:arrow_right)
      expect_active_gridcell("#{second_new_week_slot_selector}[tabindex='0']")
    end

    scenario "preserves the focused all-day cell when arrow navigation crosses weeks" do
      visit(calendar_events_path(calendar))

      all_day_cells = all(
        ".fc-agendaWeek-view .fc-day-grid .fc-bg .fc-day[data-date]"
      )
      last_date = all_day_cells.last["data-date"]
      first_new_week_date = Date.iso8601(last_date).next_day
      second_new_week_date = first_new_week_date.next_day
      last_cell_selector =
        ".fc-agendaWeek-view .fc-day-grid .fc-bg .fc-day[data-date='#{last_date}']"
      first_new_week_cell_selector =
        ".fc-agendaWeek-view .fc-day-grid .fc-bg .fc-day" \
        "[data-date='#{first_new_week_date.to_fs(:no_time)}']"
      second_new_week_cell_selector =
        ".fc-agendaWeek-view .fc-day-grid .fc-bg .fc-day" \
        "[data-date='#{second_new_week_date.to_fs(:no_time)}']"

      page.execute_script(<<~JS)
        window.calendarFocusedAllDayCell = document.querySelector(#{last_cell_selector.to_json});
        window.calendarFocusedAllDayCell.focus();
      JS
      find(last_cell_selector).send_keys(:arrow_right)

      expect_active_gridcell("#{first_new_week_cell_selector}[tabindex='0']")
      first_new_week_label =
        expected_date_label(
          first_new_week_date,
          prefix: "All Day",
          count: nil,
          include_week_context: true
        )
      expect(page).to have_css(
        "#{first_new_week_cell_selector}[aria-label='#{first_new_week_label}']"
      )
      expect(page).to have_css(
        "#calendar-grid-focus-live-region[aria-live='assertive'][aria-atomic='true']",
        text: first_new_week_label,
        visible: false
      )
      expect(page.evaluate_script(
        "window.calendarFocusedAllDayCell === document.activeElement"
      )).to eq(true)

      find(first_new_week_cell_selector).send_keys(:arrow_right)
      expect_active_gridcell("#{second_new_week_cell_selector}[tabindex='0']")
    end

    scenario "exposes selected, active, and today states on date cells" do
      visit(calendar_events_path(calendar))
      find(".fc-month-button").click

      today = Time.zone.today
      today_date = today.to_fs(:no_time)
      today_label = expected_date_label(today)
      selected_cell_selector =
        ".fc-month-view .fc-bg .fc-day[data-date][tabindex='0'][aria-selected='true']"

      expect(page).to have_css(".fc-month-view .fc-day[data-date='#{today_date}'][aria-current='date']")
      expect(page).to have_css(
        ".fc-month-view .fc-bg .fc-day[data-date='#{today_date}'][aria-label='#{today_label}']"
      )
      expect(page).to have_css(selected_cell_selector, count: 1)

      selected_date_before_click = find(selected_cell_selector)["data-date"]
      target_date = page.evaluate_script(<<~JS)
        (() => {
          const cells = Array.from(document.querySelectorAll(".fc-month-view .fc-bg .fc-day[data-date]"))
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
        ".fc-month-view .fc-bg .fc-day[data-date][tabindex='0'][aria-selected='true'].fc-gather-grid-active",
        count: 1
      )
      target_label = page.evaluate_script(
        "`${moment('#{target_date}', 'YYYY-MM-DD').format('dddd, MMMM D, YYYY')}, No events`"
      )
      expect(page).to have_css(
        ".fc-month-view .fc-bg .fc-day[data-date='#{target_date}']" \
        "[aria-label='#{target_label}'][tabindex='0']"
      )
      expect(page).to have_css(".fc-month-view .fc-day[data-date='#{today_date}'][aria-current='date']")
      expect(page).to have_css(".fc-month-view .fc-day[data-date][aria-selected='true']", count: 1)

      next_month_date = today.next_month.beginning_of_month.to_fs(:no_time)
      page.execute_script("$('#calendar').fullCalendar('next')")
      expect(page).to have_css(".fc-month-view .fc-bg .fc-day[data-date='#{next_month_date}'][aria-label]")
      expect(page).to have_css(".fc-month-view .fc-bg .fc-day[data-date][aria-label]", minimum: 1)
      rerendered_cell = page.evaluate_script(<<~JS)
        (() => {
          const selector = ".fc-month-view .fc-bg .fc-day[data-date='#{next_month_date}']";
          const cell = document.querySelector(selector);
          const date = cell.getAttribute("data-date");

          return {
            date,
            label: cell.getAttribute("aria-label"),
            expectedLabel: `${moment(date, "YYYY-MM-DD").format("dddd, MMMM D, YYYY")}, No events`
          };
        })()
      JS
      expect(rerendered_cell["label"]).to eq(rerendered_cell["expectedLabel"])
    end
  end

  def expected_date_label(date, prefix: nil, count: "No events", include_week_context: false)
    date_label = page.evaluate_script(
      "moment('#{date.to_fs(:no_time)}', 'YYYY-MM-DD').format('dddd, MMMM D, YYYY')"
    )
    if date == Time.zone.today
      date_label = "Today, #{date_label}"
    elsif include_week_context && current_week?(date)
      date_label = "This week, #{date_label}"
    end
    [prefix, date_label, count].compact.join(", ")
  end

  def expected_time_slot_label(date, time, include_week_context: false)
    date_label = page.evaluate_script(
      "moment('#{date.to_fs(:no_time)}', 'YYYY-MM-DD').format('dddd, MMMM D, YYYY')"
    )
    if date == Time.zone.today
      date_label = "Today, #{date_label}"
    elsif include_week_context && current_week?(date)
      date_label = "This week, #{date_label}"
    end
    time_label = page.evaluate_script(<<~JS)
      (() => {
        const time = moment(#{time.to_json}, "HH:mm:ss");
        return time.minutes() === 0 ? time.format("h A") : time.format("h mm A");
      })()
    JS
    "#{date_label}, #{time_label}"
  end

  def expected_grid_label(view_selector, view_name)
    page.evaluate_script(<<~JS)
      (() => {
        const viewSelector = #{view_selector.to_json};
        const viewName = #{view_name.to_json};
        const times = Array.from(
          document.querySelectorAll(`${viewSelector} .fc-slats tr[data-time]`)
        ).map((row) => row.getAttribute("data-time"));
        const start = moment(times[0], "HH:mm:ss");
        const end = moment(times[times.length - 1], "HH:mm:ss");
        const slotMinutes = times.length > 1
          ? moment(times[1], "HH:mm:ss").diff(start, "minutes")
          : 30;
        end.add(slotMinutes > 0 ? slotMinutes : 30, "minutes");
        const label = (time) => time.minutes() === 0
          ? time.format("h A")
          : time.format("h mm A");
        const interval = slotMinutes === 30
          ? "half-hour time slots"
          : `${slotMinutes}-minute time slots`;
        return `${viewName}. All Day row followed by ${interval} from ${label(start)} ` +
          `to ${label(end)}. Use arrow keys to navigate`;
      })()
    JS
  end

  def current_week?(date)
    date.beginning_of_week(:sunday) == Time.zone.today.beginning_of_week(:sunday)
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
    expect(page).to have_css("#{selector}:focus")
  end

  def expect_sidebar_calendar_list_landmark
    expect(page).to have_css(
      "section[role='region'][aria-labelledby='sidebar-calendar-list-heading'][tabindex='-1'] " \
        "h3#sidebar-calendar-list-heading",
      text: "Calendars"
    )
    expect(page).to have_css(
      "section[role='region'][aria-labelledby='sidebar-calendar-list-heading'] h4.group",
      text: "Reservations"
    )
  end
end
