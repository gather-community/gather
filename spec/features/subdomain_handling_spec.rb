require "rails_helper"

feature "subdomain handling" do
  let(:apex) { Settings.url.host_without_port }
  let!(:user) { create(:user) }

  around do |example|
    stub_omniauth(google_oauth2: {email: user.google_email}) do
      example.run
    end
  end

  scenario "visiting subdomain and logging in" do
    switch_to_subdomain("foo") do
      visit root_path
      expect(current_url).to have_subdomain("foo")
      expect_valid_login_link_and_click
      expect(page).to have_content(user.name)
      expect(current_url).to have_subdomain("foo")
    end
  end

  scenario "visiting invalid subdomain" do

  end

  scenario "visiting valid but unpermitted subdomain and logging in" do
    # login should work but should get 403 once logged in
  end

  scenario "visiting subdomain with path and logging in" do
    # should return you to path if allowed
  end

  scenario "visiting other community subdomain root and logging in" do
    # should redirect you back to the other community root (directory) if you have access
  end

  scenario "visiting other community subdomain meals path and logging in" do
    # should redirect you back to the appropriate meals page if you have access
  end

  scenario "visiting apex domain and logging in" do
    # should take you to home page under your community subdomain
  end

  scenario "visiting apex domain meals path and logging in" do
    # should take you to home page under your community subdomain
  end
end
