require "rails_helper"

feature "resources", js: true do
  include_context "photo uploads"

  let(:actor) { create(:admin) }
  let(:edit_path) { edit_reservations_resource_path(resources.first) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  it_behaves_like "photo upload widget"

  context "with no resources" do
    scenario "index" do
      visit(reservations_resources_path)
      expect(page).to have_title("Resources")
      expect(page).to have_content("No resources found.")
    end
  end

  context "with resources" do
    let!(:resources) { create_list(:resource, 2) }

    scenario "index" do
      visit(reservations_resources_path)
      expect(page).to have_title("Resources")
      expect(page).to have_css("table.index tr", count: 3) # Header plus two rows
    end

    scenario "create and update" do
      visit(reservations_resources_path)
      click_link("Create Resource")
      expect_no_image_and_drop_file("cooper.jpg")
      click_on("Create Resource")

      expect_validation_error
      expect_image_upload(mode: :existing, path: /cooper/)
      fill_in("Name", with: "Foo Bar")
      fill_in("Abbreviation", with: "Bar")
      select("Yes", from: "Can Host Meals?")
      select("Month", from: "Calendar View")
      fill_in("Guidelines", with: "Don't do bad stuff")
      click_on("Create Resource")
      expect_success

      click_link("Foo Bar")
      expect(page).to have_title("Resource: Foo Bar")
      expect_image_upload(mode: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      expect_image_upload(mode: :dz_preview)
      fill_in("Name", with: "Baz Qux")
      click_on("Update Resource")

      expect_success
      expect(page).to have_css("table tr td", text: "Baz Qux")
    end

    scenario "deactivate/activate/delete" do
      visit(edit_reservations_resource_path(resources.first))
      accept_confirm { click_on("Deactivate") }
      expect_success
      click_on("#{resources.first.name} (Inactive)")
      click_on("reactivate it")
      expect_success
      expect(page).not_to have_content("#{resources.first.name} (Inactive)")
      click_on(resources.first.name)
      accept_confirm { click_on("Delete") }
      expect_success
      expect(page).not_to have_content(resources.first.name)
    end
  end
end
