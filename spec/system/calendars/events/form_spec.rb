# frozen_string_literal: true

require "rails_helper"

describe "event form", js: true do
  let(:user) { create(:user) }
  let(:calendar) { create(:calendar, :with_shared_guidelines) }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  describe "new, validation, edit" do
    scenario do
      visit(new_calendars_event_path(calendar_id: calendar.id))
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
  end

  describe "pre_notice" do
    let!(:protocol) { create(:calendar_protocol, calendars: [calendar], pre_notice: "May be bed bugs!") }

    scenario "should show warning" do
      visit(new_calendars_event_path(calendar_id: calendar.id))
      expect(page).to have_content("May be bed bugs!")
    end
  end
end
