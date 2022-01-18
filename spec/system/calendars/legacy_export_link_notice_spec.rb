# frozen_string_literal: true

require "rails_helper"

describe "calendar export link notice" do
  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with legacy flag set" do
    let(:actor) { create(:admin, settings: {show_legacy_calendar_export_links: true}) }

    scenario do
      visit(root_path)
      click_on_personal_nav("Calendars")
      expect(page).to have_content("old calendar export page")
      click_on("Got it!")

      expect(page).not_to have_personal_nav("Calendars")
    end
  end

  context "without legacy flag set" do
    let(:actor) { create(:admin, settings: {}) }

    scenario do
      visit(root_path)
      expect(page).not_to have_personal_nav("Calendars")
    end
  end
end
