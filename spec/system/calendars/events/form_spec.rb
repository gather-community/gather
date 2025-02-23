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
      accept_confirm { click_on("Cancel") }
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
          create(:event, creator: user, calendar: calendar, kind: "Personal", guidelines_ok: "1",
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
        check("All-day event")
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
        expect(page).not_to have_content("All-day event")
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
end
