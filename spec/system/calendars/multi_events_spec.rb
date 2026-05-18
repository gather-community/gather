# frozen_string_literal: true

require "rails_helper"

describe "multi-event form", js: true do
  let(:community) { create(:community) }
  let(:user) { create(:user, community: community) }
  let!(:calendar1) { create(:calendar, name: "Main Hall", community: community) }
  let!(:calendar2) { create(:calendar, name: "Garden", community: community) }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  describe "creating a multi-calendar event" do
    scenario "basic create with one calendar" do
      visit(new_calendars_multi_event_path)

      fill_in("Event Name", with: "Community Meeting")
      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1)
      # pick_datetime after AJAX re-render verifies pickers are re-initialized.
      pick_datetime_safely(".calendars_event_starts_at", day: 10, hour: 10)
      pick_datetime_safely(".calendars_event_ends_at", day: 10, hour: 11)
      click_on("Save")

      expect_success("Events created successfully")
      expect(Calendars::Event.count).to eq(1)
      expect(Calendars::Eventlet.where(calendar: calendar1).count).to eq(1)
    end

    scenario "creates one eventlet per selected calendar" do
      visit(new_calendars_multi_event_path)

      fill_in("Event Name", with: "Community Meeting")

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1)
      click_on("Add Calendar")
      select_calendar_in_slot(1, calendar2)
      pick_datetime_safely(".calendars_event_starts_at", day: 10, hour: 10)
      pick_datetime_safely(".calendars_event_ends_at", day: 10, hour: 11)

      click_on("Save")

      expect_success("Events created successfully")
      event = Calendars::Event.last
      expect(event.eventlets.count).to eq(2)
      expect(event.eventlets.map { |e| e.calendar.name }).to contain_exactly("Main Hall", "Garden")
    end

    scenario "shows validation error when no calendar is selected" do
      visit(new_calendars_multi_event_path)

      fill_in("Event Name", with: "Test")
      pick_datetime_safely(".calendars_event_starts_at", day: 10, hour: 10)
      pick_datetime_safely(".calendars_event_ends_at", day: 10, hour: 11)
      click_on("Save")

      expect_validation_error("At least one calendar must be selected")
    end

    scenario "removing a slot reduces eventlet count" do
      visit(new_calendars_multi_event_path)

      fill_in("Event Name", with: "Short Event")

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1)
      click_on("Add Calendar")
      select_calendar_in_slot(1, calendar2)

      # Remove the second slot
      all(".nested-fields:not(.hidden) .remove-calendar-btn").last.click
      wait_for_form_rerender

      pick_datetime_safely(".calendars_event_starts_at", day: 10, hour: 10)
      pick_datetime_safely(".calendars_event_ends_at", day: 10, hour: 11)
      click_on("Save")

      expect_success("Events created successfully")
      expect(Calendars::Eventlet.count).to eq(1)
      expect(Calendars::Eventlet.first.calendar).to eq(calendar1)
    end

    scenario "shows guidelines for all selected calendars with one checkbox" do
      calendar1.update!(guidelines: "Main Hall rules")
      calendar2.update!(guidelines: "Garden rules")

      visit(new_calendars_multi_event_path)
      fill_in("Event Name", with: "Meeting")

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1)

      expect(page).to have_content("Main Hall rules")
      expect(page).not_to have_content("Garden rules")
      expect(page).to have_unchecked_field("I agree to the above guidelines")

      click_on("Add Calendar")
      select_calendar_in_slot(1, calendar2)

      expect(page).to have_content("Main Hall rules")
      expect(page).to have_content("Garden rules")
      expect(page).to have_selector("input[type='checkbox'][name*='guidelines_ok']", count: 1)
    end

    scenario "shows events summary section after selecting a calendar" do
      visit(new_calendars_multi_event_path)
      fill_in("Event Name", with: "Test")
      # Dates must be set before calendar selection so they appear in the AJAX request
      # and the server can include them in the rendered events summary.
      pick_datetime_safely(".calendars_event_starts_at", day: 10, hour: 10)
      pick_datetime_safely(".calendars_event_ends_at", day: 10, hour: 11)

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1)

      within(".multi-event-summary") do
        expect(page).to have_content("Main Hall")
        expect(page).to have_content(Time.zone.today.year.to_s)
      end
    end
  end

  describe "customize times per calendar" do
    scenario "shows time pickers when 'Customize times' is checked" do
      visit(new_calendars_multi_event_path)

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1)

      # The customize-times-fields div starts hidden; checking the box reveals it.
      first(".nested-fields:not(.hidden) .customize-times-fields", visible: :all).tap do |div|
        expect(div).not_to be_visible
      end

      first(".nested-fields:not(.hidden)").check("Customize times")

      expect(first(".nested-fields:not(.hidden) .customize-times-fields")).to be_visible
    end

    scenario "creates eventlet with override times" do
      visit(new_calendars_multi_event_path)
      fill_in("Event Name", with: "Override Meeting")

      click_on("Add Calendar")
      select_calendar_in_slot(0, calendar1)
      click_on("Add Calendar")
      select_calendar_in_slot(1, calendar2)

      pick_datetime_safely(".calendars_event_starts_at", day: 10, hour: 10)
      pick_datetime_safely(".calendars_event_ends_at", day: 10, hour: 11)

      # Customize times on the second visible slot
      second_slot = all(".nested-fields:not(.hidden)").last
      second_slot.check("Customize times")
      set_slot_time_field(second_slot, :starts_at, "14:00")
      set_slot_time_field(second_slot, :ends_at, "15:00")

      click_on("Save")
      expect_success("Events created successfully")

      event = Calendars::Event.last
      eventlet1 = event.eventlets.find_by(calendar: calendar1)
      eventlet2 = event.eventlets.find_by(calendar: calendar2)
      expect(eventlet1.starts_at.strftime("%H:%M")).to eq("10:00")
      expect(eventlet2.starts_at.strftime("%H:%M")).to eq("14:00")
    end
  end

  describe "on-blur validation with touched-tracking" do
    # The Stimulus controller fires a background rerender (debounced) when an
    # input loses focus, sending a list of touched field names. The server
    # filters validation errors so untouched fields stay quiet, and :base
    # errors are hidden until real form submission.

    scenario "shows error for the touched field only" do
      visit(new_calendars_multi_event_path)

      # Set an over-length name via JS (the input has maxlength=24 that blocks fill_in),
      # then blur to trigger the touched-field rerender.
      set_value_over_maxlength("calendars_event_name", "X" * (Calendars::EventForm::NAME_MAX_LENGTH + 1))
      wait_for_form_rerender

      within(".calendars_event_name") do
        expect(page).to have_content("is too long")
      end
      # starts_at is blank and required, but the user hasn't touched it — no error yet.
      expect(page).to have_no_css(".calendars_event_starts_at .help-block")
    end

    scenario "hides :base errors until form is submitted" do
      visit(new_calendars_multi_event_path)

      fill_in("Event Name", with: "Meeting")
      find("body").click
      wait_for_form_rerender

      # "At least one calendar must be selected" is a :base error.
      # It should NOT appear from a blur-triggered rerender.
      expect(page).to have_no_content("At least one calendar must be selected")

      # Submitting reveals all errors including :base.
      click_on("Save")
      expect_validation_error("At least one calendar must be selected")
    end

    scenario "preserves existing field errors across subsequent blur rerenders" do
      visit(new_calendars_multi_event_path)

      set_value_over_maxlength("calendars_event_name", "X" * (Calendars::EventForm::NAME_MAX_LENGTH + 1))
      wait_for_form_rerender

      within(".calendars_event_name") { expect(page).to have_content("is too long") }

      # Touching a second field should not clear the name error.
      fill_in("Note", with: "some note")
      find("body").click
      wait_for_form_rerender

      within(".calendars_event_name") { expect(page).to have_content("is too long") }
    end

    scenario "clears a field error when the value becomes valid" do
      visit(new_calendars_multi_event_path)

      set_value_over_maxlength("calendars_event_name", "X" * (Calendars::EventForm::NAME_MAX_LENGTH + 1))
      wait_for_form_rerender

      within(".calendars_event_name") { expect(page).to have_content("is too long") }

      fill_in("Event Name", with: "OK")
      find("body").click
      wait_for_form_rerender

      expect(page).to have_no_css(".calendars_event_name .help-block")
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

      expect(page).to have_selector(".nested-fields:not(.hidden)", count: 2)
      fill_in("Event Name", with: "Updated Event")
      click_on("Save")

      expect_success("Events updated successfully")
      expect(event.reload.name).to eq("Updated Event")
    end
  end

  private

  # Sets a time override field within a specific slot element via JavaScript,
  # bypassing the time picker widget (slot overrides use time_picker, not datetime_picker).
  def set_slot_time_field(slot, field, value)
    input = slot.find("input[name*='calendar_slots'][name*='[#{field}]']")
    execute_script("arguments[0].value = arguments[1]", input.native, value)
  end

  # Sets an input's value via JS (bypassing HTML maxlength) and fires the
  # focus/blur pair so the Stimulus controller registers the field as touched.
  def set_value_over_maxlength(input_id, value)
    execute_script(<<~JS, input_id, value)
      var el = document.getElementById(arguments[0]);
      el.focus();
      el.value = arguments[1];
      el.blur();
    JS
  end

  # Wraps pick_datetime to wait for any in-flight blur-triggered rerender
  # before opening the picker (otherwise the picker DOM can be morphed away
  # mid-interaction).
  def pick_datetime_safely(*args, **kwargs)
    wait_for_form_rerender
    pick_datetime(*args, **kwargs)
  end

  # Selects a calendar in the nth visible slot and waits for the AJAX re-render.
  # Uses execute_script to bypass Selenium's disabled? DOM query which can crash
  # older headless Chrome versions on ARM64.
  def select_calendar_in_slot(index, calendar)
    wait_for_form_rerender
    slot = all(".nested-fields:not(.hidden)")[index]
    select_el = slot.find("select[name*='[calendar_id]']")
    execute_script(
      "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('change', {bubbles: true}))",
      select_el.native,
      calendar.id.to_s
    )
    wait_for_form_rerender
  end

  # Waits for any in-flight AJAX re-render to complete by polling the loading
  # indicator. Rerenders are debounced ~50ms on the client, so we wait up to
  # 1s for the indicator to appear, then up to 5s for it to hide.
  def wait_for_form_rerender
    if page.has_css?("#glb-load-ind:not(.hiding)", wait: 1)
      expect(page).to have_no_css("#glb-load-ind:not(.hiding)", wait: 5)
    end
  end
end
