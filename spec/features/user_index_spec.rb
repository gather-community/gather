require "rails_helper"

feature "user index" do
  let(:user) { create(:user) }

  around { |ex| with_user_home_subdomain(user) { ex.run } }

  before do
    login_as(user, scope: :user)
  end

  scenario "download csv" do
    visit "/users"
    expect(page).to have_css("a", text: "Download as CSV")
    click_on("Download as CSV")
    expect(page.response_headers['Content-Disposition']).to include("filename=\"directory.csv\"")
  end
end
