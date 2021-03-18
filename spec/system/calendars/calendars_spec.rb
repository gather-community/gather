# frozen_string_literal: true

require "rails_helper"

describe "calendars", js: true do
  include_context "photo uploads"

  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with no calendars" do
    scenario "index" do
      visit(calendars_path)
      expect(page).to have_title("Calendars")
      expect(page).to have_content("No calendars found.")
    end
  end

  context "with calendars" do
    let!(:calendars) { create_list(:calendar, 2) }
    let(:edit_path) { edit_calendar_path(calendars.first) }

    it_behaves_like "photo upload widget"

    scenario "index" do
      visit(calendars_path)
      expect(page).to have_title("Calendars")
      expect(page).to have_css("table.index tr", count: 3) # Header plus two rows
    end

    scenario "create and update" do
      visit(calendars_path)
      click_link("Create Calendar")
      expect_no_image_and_drop_file("cooper.jpg")
      click_button("Save")

      expect_validation_error
      expect_image_upload(state: :existing, path: /cooper/)
      fill_in("Name", with: "Foo Bar")
      fill_in("Abbreviation", with: "Bar")
      select("Yes", from: "Can Host Meals?")
      select("Month", from: "Calendar View")
      fill_in("Guidelines", with: "Don't do bad stuff")
      click_button("Save")
      expect_success

      click_link("Foo Bar")
      expect(page).to have_title("Calendar: Foo Bar")
      expect_image_upload(state: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      expect_image_upload(state: :new)
      fill_in("Name", with: "Baz Qux")
      click_button("Save")

      expect_success
      expect(page).to have_css("table tr td", text: "Baz Qux")
    end

    scenario "deactivate/activate/delete" do
      visit(edit_calendar_path(calendars.first))
      accept_confirm { click_on("Deactivate") }
      expect_success
      click_on("#{calendars.first.name} (Inactive)")
      click_on("reactivate it")
      expect_success
      expect(page).not_to have_content("#{calendars.first.name} (Inactive)")
      click_on(calendars.first.name)
      accept_confirm { click_on("Delete") }
      expect_success
      expect(page).not_to have_content(calendars.first.name)
    end
  end
end
