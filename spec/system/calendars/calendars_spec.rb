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
    let!(:group) { create(:calendar_group, name: "Group") }
    let!(:calendars) do
      [
        create(:calendar, name: "Cal1", group: nil),
        create(:calendar, name: "Cal2", group: group),
        create(:calendar, name: "Cal3", group: group),
        create(:calendar, name: "Cal4", group: nil),
        create(:calendar, name: "Cal5", group: nil)
      ]
    end
    let(:edit_path) { edit_calendar_path(calendars.first) }

    it_behaves_like "photo upload widget"

    scenario "index and rank change" do
      visit(calendars_path)
      expect(page).to have_title("Calendars")
      expect(page).to have_css("table.index tr", count: 7) # Header plus 6 rows
      expect(page).to have_content(/Group.+  Cal2.+  Cal3.+Cal1.+Cal4.+Cal5/m)
      all(".move-links .down")[0].click
      expect(page).to have_content(/Cal1.+Group.+  Cal2.+  Cal3.+Cal4.+Cal5/m)
      all(".move-links .up")[5].click
      expect(page).to have_content(/Cal1.+Group.+  Cal2.+  Cal3.+Cal5.+Cal4/m)
      all(".move-links .up")[3].click
      expect(page).to have_content(/Cal1.+Group.+  Cal3.+  Cal2.+Cal5.+Cal4/m)
    end

    scenario "create and update calendar" do
      visit(calendars_path)
      click_link("Create Calendar")
      expect_no_image_and_drop_file("cooper.jpg")
      click_button("Save")

      expect_validation_error
      expect_image_upload(state: :existing, path: /cooper/)
      fill_in("Name", with: "Foo Bar")
      fill_in("Abbreviation", with: "Bar")
      select("Yes", from: "Can host meals?")
      select("Month", from: "Calendar View")
      fill_in("Guidelines", with: "Don't do bad stuff")
      click_button("Save")
      expect_success
      expect(page).to have_content(/Group.+  Cal2.+  Cal3.+Cal1.+Cal4.+Cal5.+Foo Bar/m)

      click_link("Foo Bar")
      expect(page).to have_title("Calendar: Foo Bar")
      expect_image_upload(state: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      expect_image_upload(state: :new)
      fill_in("Name", with: "Baz Qux")
      all(".swatch")[3].click
      expect(page).to have_field("Color", with: Calendars::Calendar::COLORS[3])
      select("Group", from: "Calendar Group")
      click_button("Save")
      expect_success
      expect(page).to have_content(/Group.+  Cal2.+  Cal3.+  Baz Qux.+Cal1.+Cal4.+Cal5/m)

      expect(page).to have_css("table tr td", text: "Baz Qux")
    end

    scenario "deactivate/activate/delete calendar" do
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

    scenario "create, update, destroy group" do
      visit(calendars_path)
      click_on("Create Group")
      click_button("Save")
      expect_validation_error

      fill_in("Name", with: "Group2")
      click_button("Save")
      expect_success
      expect(page).to have_content(/Group.+  Cal2.+  Cal3.+Cal1.+Cal4.+Cal5.+Group2/m)

      click_on("Group2")
      fill_in("Name", with: "Group2.1")
      click_button("Save")
      expect_success
      expect(page).to have_content("Group2.1")

      click_on("Group")
      puts "--------------------------------------------------"
      accept_confirm { click_on("Delete") }
      expect_success
      # Cal1 and Cal3 have the same rank (2) after group is deleted. Cal1 comes first
      # because it is first alphabetically.
      expect(page).to have_content(/Cal2.+Cal1.+Cal3.+Cal4.+Cal5.+Group2.1/m)
    end

    context "with system calendar" do
      let!(:calendar) { create(:community_meals_calendar, name: "Cmty Meals") }

      scenario "edit system calendar" do
        visit(calendars_path)
        click_on("Cmty Meals")
        fill_in("Name", with: "Cmty Mealz")
        drop_in_dropzone(fixture_file_path("chomsky.jpg"))
        click_on("Save")

        expect_success
        click_on("Cmty Mealz")
        expect_image_upload(state: :existing, path: /chomsky/)

        message = accept_confirm { click_on("Deactivate") }
        expect(message).to match(/Are you sure you want to/) # Not missing translation
        expect_success
        expect(page).to have_content("Cmty Mealz (Inactive)")
      end
    end
  end
end
