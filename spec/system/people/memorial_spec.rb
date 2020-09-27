# frozen_string_literal: true

require "rails_helper"

describe "memorials", js: true do
  let(:page_path) { people_memorials_path }
  let!(:inactive_user) do
    create(:user, :inactive, first_name: "John", last_name: "Smith", birthday_str: "1950-01-02")
  end

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "as admin" do
    let(:actor) { create(:admin) }

    scenario "index, create, update, destroy" do
      visit(page_path)
      expect(page).to have_content("No memorials found")
      click_link("Create Memorial")

      select2("John Smith", from: find("select.assoc_select2"))
      fill_in("Death Year", with: "2020")
      fill_in("Obituary", with: "Nice chap")
      expect(page).to have_field("Birth Year", with: "1950")
      click_on("Save")

      expect_success
      click_on("John Smith")
      expect(page).to have_content("Obituary")
      expect(page).to have_content("Community Memories")

      write_and_edit_message

      within(".action-links") { click_link("Edit") }
      fill_in("Obituary", with: "New Obituary")
      click_button("Save")

      expect_success
      click_link("John Smith")
      within(".action-links") { click_link("Edit") }
      within(".action-links") { accept_confirm { click_link("Delete") } }

      expect_success
      expect(page).to have_content("No memorials found")
    end
  end

  context "as regular user" do
    let(:actor) { create(:user) }
    let!(:memorial) { create(:memorial, user: inactive_user) }
    let!(:memorial_message) { create(:memorial_message, memorial: memorial, body: "Nice guy") }

    scenario "index, create, update, destroy" do
      visit(page_path)
      click_link("John Smith")

      expect(page).to have_content("Nice guy")
      expect(page).not_to have_css("a", text: "Edit")

      write_and_edit_message
    end
  end

  def write_and_edit_message
    # Test Save button being hidden until fill in content
    expect(page).not_to have_content("Save")
    find("#people_memorial_message_body").set("My new message")
    click_button("Save")

    expect_success(/Thanks/)
    expect(page).to have_content("My new message")
    within(all(".message").last) { click_link("Edit") }
    click_button("Cancel")
    within(all(".message").last) do
      click_link("Edit")
    end
    find("#people_memorial_message_body").set("My newer message")
    click_button("Save")

    expect_success
    expect(page).to have_content("My newer message")
    within(all(".message").last) { accept_confirm { click_link("Delete") } }

    expect_success
    expect(page).not_to have_content("My newer message")
  end
end
