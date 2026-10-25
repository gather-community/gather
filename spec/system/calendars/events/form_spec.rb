# frozen_string_literal: true

require "rails_helper"

describe "event form", js: true do
  let(:community) { create(:community, settings: {calendars: {kinds: "Official,Personal"}}) }
  let(:user) { create(:user, community: community) }
  let(:calendar) { create(:calendar, :with_shared_guidelines, community: community) }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  describe "new, validation, edit" do
    scenario do
      visit(new_calendar_event_path(calendar))
      fill_in("Event Name", with: "Stuff")
      click_on("Save")
      expect_validation_error("You must agree to the guidelines")
      check("I agree to the above")
      click_on("Save")
      expect_success

      find("div.fc-title", text: "Stuff").click
      click_on("Edit")
      fill_in("Event Name", with: "Stuffy Stuff")
      click_on("Save")
      expect_success
      expect(page).to have_content("Stuffy Stuff")

      find("div.fc-title", text: "Stuff").click
      click_on("Edit")
      click_on("Delete")
      click_modal_button
      expect_success
      expect(page).to have_title(calendar.name)
      expect(page).not_to have_content("Stuffy Stuff")
    end

    context "with kind-based protocol" do
      let!(:protocol1) do
        create(:calendar_protocol, community: community, calendars: [calendar], requires_kind: true)
      end
      let!(:protocol2) do
        create(:calendar_protocol, community: community, calendars: [calendar], max_days_per_year: 1,
          kinds: ["Personal"])
      end
      let!(:existing_event) do
        Timecop.freeze("2022-01-01 12:00") do
          create(:event, creator: user, calendar: calendar, kind: "Personal",
            starts_at: "2022-01-01 13:00", ends_at: "2022-01-01 14:00")
        end
      end

      scenario "attempt to create event violating policy" do
        Timecop.freeze("2022-01-02 12:00") do
          visit(new_calendar_event_path(calendar))
          fill_in("Event Name", with: "Stuff")
          select("Personal", from: "Type")
          check("I agree to the above")
          click_on("Save")
          expect_validation_error("You can book at most")
        end
      end
    end
  end

  describe "all day events" do
    context "with a calendar that supports them" do
      scenario do
        visit(new_calendar_event_path(calendar, start: "2021-09-29 08:00", end: "2021-09-29 09:00"))
        fill_in("Event Name", with: "Stuff")
        check("I agree to the above")

        expect(evaluate_script("$('.datetimepicker input').val()")).to include("8:00am")
        check("All-Day Event")
        expect(evaluate_script("$('.datetimepicker input').val()")).not_to include("8:00am")

        click_on("Save")
        expect_success

        click_on("Stuff")
        expect(page).not_to have_content("12:00am")

        click_on("Edit")
        expect(page).to have_field("calendars_event_all_day", checked: true)
        expect(evaluate_script("$('.datetimepicker input').val()")).not_to include("12:00am")
      end
    end

    context "with a calendar that doesn't support them" do
      let!(:protocol) { create(:calendar_protocol, calendars: [calendar], fixed_start_time: "8:00am") }

      scenario do
        visit(new_calendar_event_path(calendar))
        expect(page).not_to have_content("All-Day Event")
      end
    end
  end

  describe "pre_notice" do
    let!(:protocol) { create(:calendar_protocol, calendars: [calendar], pre_notice: "May be bed bugs!") }

    scenario "should show warning" do
      visit(new_calendar_event_path(calendar))
      expect(page).to have_content("May be bed bugs!")
    end
  end

  # The form's own behavior in the browser, pinned so it survives the move to Stimulus
  # (calendars--event-form).
  describe "behavior in the browser" do
    def form_dirty?
      evaluate_script("$('.calendars--event-form').dirtyForms('isDirty')")
    end

    def start_time_text
      evaluate_script("$('.calendars_event_starts_at .datetimepicker input').val()")
    end

    context "with pre-notices limited to some kinds" do
      # The Type field only appears when a protocol requires one.
      let!(:general) do
        create(:calendar_protocol, calendars: [calendar], pre_notice: "Mind the stairs", requires_kind: true)
      end
      let!(:personal) do
        create(:calendar_protocol, calendars: [calendar], kinds: ["Personal"], pre_notice: "Personal notice")
      end
      let!(:official) do
        create(:calendar_protocol, calendars: [calendar], kinds: ["Official"], pre_notice: "Official notice")
      end

      scenario "shows only the notices for the chosen kind, and always the general one" do
        visit(new_calendar_event_path(calendar))
        expect(page).to have_content("Mind the stairs")
        expect(page).not_to have_content("Personal notice")
        expect(page).not_to have_content("Official notice")

        select("Personal", from: "Type")
        expect(page).to have_content("Personal notice")
        expect(page).not_to have_content("Official notice")

        select("Official", from: "Type")
        expect(page).to have_content("Official notice")
        expect(page).not_to have_content("Personal notice")
        expect(page).to have_content("Mind the stairs")
      end

      scenario "shows the notice for an existing event's kind when editing" do
        event = create(:event, calendar: calendar, creator: user, kind: "Official")
        visit(edit_calendars_event_path(event))
        expect(page).to have_content("Official notice")
        expect(page).not_to have_content("Personal notice")
      end
    end

    # The picker redraws the field once the page loads. It should still read as Gather's dates do, with
    # the day padded. (Rails' own version has two spaces before the hour, so this is the picker's.)
    scenario "shows dates in Gather's format once the picker has loaded" do
      visit(new_calendar_event_path(calendar, start: "2030-10-01 08:00", end: "2030-10-01 09:00"))
      expect(page).to have_field("Start Time", with: "Tue Oct 01 2030 8:00am")
    end

    scenario "unticking all-day brings the time back" do
      visit(new_calendar_event_path(calendar, start: "2021-09-29 08:00", end: "2021-09-29 09:00"))
      check("All-Day Event")
      expect(start_time_text).not_to include("8:00am")
      uncheck("All-Day Event")
      expect(start_time_text).to include("8:00am")
    end

    scenario "moving the start moves the end by as much" do
      visit(new_calendar_event_path(calendar, start: "2030-09-29 08:00", end: "2030-09-29 09:30"))
      execute_script("$('.calendars_event_starts_at .datetimepicker').data('DateTimePicker')" \
        ".date(moment('2030-10-01T10:15'))")
      expect(evaluate_script("$('.calendars_event_ends_at .datetimepicker input').val()"))
        .to match(/Oct 0?1 2030 11:45am/)
    end

    # Its pickers show only dates, while it ends at 11:59pm, which once read as a change.
    scenario "doesn't see an untouched all-day event as changed" do
      event = create(:event, calendar: calendar, creator: user, all_day: true,
        starts_at: Time.zone.parse("2030-09-29 00:00"), ends_at: Time.zone.parse("2030-09-29 23:59:59"))
      visit(edit_calendars_event_path(event))
      expect(page).to have_field("Start Time", with: /Sep 29 2030/)
      expect(form_dirty?).to be(false)
    end

    scenario "notices unsaved changes" do
      visit(new_calendar_event_path(calendar))
      expect(form_dirty?).to be(false)
      fill_in("Event Name", with: "Stuff")
      # DirtyForms notices on change, which fires when the field loses focus.
      find("#calendars_event_name").send_keys(:tab)
      expect(form_dirty?).to be(true)
    end

    context "as an admin" do
      let(:user) { create(:admin, community: community) }

      scenario "chooses the creator with a searchable picker" do
        visit(new_calendar_event_path(calendar))
        expect(page).to have_css(".calendars_event_creator_id .select2-container")
      end
    end
  end
end
