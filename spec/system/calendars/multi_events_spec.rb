# frozen_string_literal: true

require "rails_helper"

describe "multi-event form", js: true do
  let(:community) { create(:community) }
  let(:user) { create(:user, community: community) }
  let(:calendar1) { create(:calendar, name: "Main Hall", community: community) }
  let(:calendar2) { create(:calendar, name: "Garden", community: community) }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  describe "creating a multi-calendar event" do
    scenario "basic create with one calendar" do
      visit(new_calendars_multi_event_path)

      fill_in("Event Name", with: "Community Meeting")
      fill_in_datetime(:starts_at, "2026-05-10 10:00am")
      fill_in_datetime(:ends_at, "2026-05-10 11:00am")
      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1.name)
      click_on("Save")

      expect_success("Events created successfully")
      expect(Calendars::Event.count).to eq(1)
      expect(Calendars::Eventlet.where(calendar: calendar1).count).to eq(1)
    end

    scenario "creates one eventlet per selected calendar" do
      visit(new_calendars_multi_event_path)

      fill_in("Event Name", with: "Community Meeting")
      fill_in_datetime(:starts_at, "2026-05-10 10:00am")
      fill_in_datetime(:ends_at, "2026-05-10 11:00am")

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1.name)
      click_on("Add Calendar")
      select_calendar_in_slot(1, calendar2.name)

      click_on("Save")

      expect_success("Events created successfully")
      event = Calendars::Event.last
      expect(event.eventlets.count).to eq(2)
      expect(event.eventlets.map { |e| e.calendar.name }).to contain_exactly("Main Hall", "Garden")
    end

    scenario "shows validation error when no calendar is selected" do
      visit(new_calendars_multi_event_path)

      fill_in("Event Name", with: "Test")
      fill_in_datetime(:starts_at, "2026-05-10 10:00am")
      fill_in_datetime(:ends_at, "2026-05-10 11:00am")
      click_on("Save")

      expect_validation_error("At least one calendar must be selected")
    end

    scenario "shows guidelines for all selected calendars with one checkbox" do
      calendar1.update!(guidelines: "Main Hall rules")
      calendar2.update!(guidelines: "Garden rules")

      visit(new_calendars_multi_event_path)
      fill_in("Event Name", with: "Meeting")
      fill_in_datetime(:starts_at, "2026-05-10 10:00am")
      fill_in_datetime(:ends_at, "2026-05-10 11:00am")

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1.name)

      # Wait for AJAX re-render to show guidelines for calendar1
      expect(page).to have_content("Main Hall rules")
      expect(page).not_to have_content("Garden rules")
      expect(page).to have_unchecked_field("I agree to the above guidelines")

      click_on("Add Calendar")
      select_calendar_in_slot(1, calendar2.name)

      # After re-render, both sets of guidelines should be shown
      expect(page).to have_content("Main Hall rules")
      expect(page).to have_content("Garden rules")

      # Only one checkbox for accepting all
      expect(page).to have_selector("input[type='checkbox'][name*='guidelines_ok']", count: 1)
    end

    scenario "shows events summary section after selecting a calendar" do
      visit(new_calendars_multi_event_path)
      fill_in("Event Name", with: "Test")
      fill_in_datetime(:starts_at, "2026-05-10 10:00am")
      fill_in_datetime(:ends_at, "2026-05-10 11:00am")

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1.name)

      within(".multi-event-summary") do
        expect(page).to have_content("Main Hall")
        # Date formatted via I18n.l
        expect(page).to have_content("2026")
      end
    end
  end

  describe "customize times per calendar" do
    scenario "shows time pickers when 'Customize times' is checked" do
      visit(new_calendars_multi_event_path)
      fill_in("Event Name", with: "Overlap Event")
      fill_in_datetime(:starts_at, "2026-05-10 10:00am")
      fill_in_datetime(:ends_at, "2026-05-10 11:00am")

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1.name)

      within(".nested-fields:first-child") do
        check("Customize times")
        expect(page).to have_selector(".customize-times-fields", visible: true)
      end
    end

    scenario "creates eventlet with override times" do
      visit(new_calendars_multi_event_path)
      fill_in("Event Name", with: "Override Meeting")
      fill_in_datetime(:starts_at, "2026-05-10 10:00am")
      fill_in_datetime(:ends_at, "2026-05-10 11:00am")

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1.name)
      click_on("Add Calendar")
      select_calendar_in_slot(1, calendar2.name)

      # Customize times on the second slot
      within(all(".nested-fields").last) do
        check("Customize times")
        fill_in_time(:starts_at, "2:00pm")
        fill_in_time(:ends_at, "3:00pm")
      end

      click_on("Save")
      expect_success("Events created successfully")

      event = Calendars::Event.last
      eventlet1 = event.eventlets.find_by(calendar: calendar1)
      eventlet2 = event.eventlets.find_by(calendar: calendar2)
      expect(eventlet1.starts_at.strftime("%H:%M")).to eq("10:00")
      expect(eventlet2.starts_at.strftime("%H:%M")).to eq("14:00")
    end
  end

  describe "editing a multi-calendar event" do
    let!(:event) do
      ev = create(:event, creator: user, calendar: calendar1, name: "Old Event",
        starts_at: "2026-05-10 10:00", ends_at: "2026-05-10 11:00",
        dont_sync_eventlet: true)
      create(:eventlet, event: ev, calendar: calendar1, starts_at: ev.starts_at, ends_at: ev.ends_at)
      create(:eventlet, event: ev, calendar: calendar2, starts_at: ev.starts_at, ends_at: ev.ends_at)
      ev
    end

    scenario "loads existing calendars into slots and can update" do
      visit(edit_calendars_multi_event_path(event))

      expect(page).to have_selector(".nested-fields", count: 2)
      fill_in("Event Name", with: "Updated Event")
      click_on("Save")

      expect_success("Events updated successfully")
      expect(event.reload.name).to eq("Updated Event")
    end
  end

  private

  def fill_in_datetime(field, value)
    # Finds the datetimepicker input for the field and fills it.
    input = find("input[name*='[#{field}]']:not([name*='calendar_slots'])")
    input.fill_in(with: value)
  rescue Capybara::ElementNotFound
    fill_in(field.to_s.humanize, with: value)
  end

  def fill_in_time(field, value)
    input = find("input[name*='calendar_slots'][name*='[#{field}]']", match: :first)
    input.fill_in(with: value)
  end

  def select_calendar_in_slot(index, calendar_name)
    # Trigger AJAX re-render by selecting a calendar in the nth slot.
    slot = all(".nested-fields")[index]
    within(slot) { select(calendar_name, from: "Calendar") }
    # Wait for AJAX re-render to complete.
    sleep 0.5
  end
end
