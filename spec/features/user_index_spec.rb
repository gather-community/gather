require "rails_helper"

feature "user index" do
  let(:user) { create(:user) }
  let(:admin) { create(:admin) }
  let(:inactive) { create(:user, :inactive, first_name: "Longgone") }

  around { |ex| with_user_home_subdomain(user) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  context "as user" do
    let(:actor) { user }

    scenario "download csv" do
      visit "/users"
      expect(page).to have_css("a", text: "Download as CSV")
      click_on("Download as CSV")
      expect(page.response_headers['Content-Disposition']).to include("filename=\"directory.csv\"")
    end

    scenario "table view", js: true do
      inactive

      visit "/users"
      select_lens(:user_view, "Table")
      expect(page).to have_css("table.index tr td", text: user.name)
      expect(page).not_to have_content("Longgone")
    end
  end

  context "as admin" do
    let(:actor) { admin }

    scenario "table with inactive view", js: true do
      inactive

      visit "/users"
      select_lens(:user_view, "Table w/ Inactive")
      expect(page).to have_css("table.index tr td", text: user.name)
      expect(page).to have_content("Longgone")
    end
  end
end
