# frozen_string_literal: true

require "rails_helper"

describe "inactive user" do
  let(:user) { create(:user, :inactive) }
  let!(:account) { create(:account, household: user.household) }

  before do
    stub_omniauth(google_oauth2: {email: user.google_email})
  end

  scenario "visiting page as inactive", js: true do
    visit root_path
    expect_sign_in_with_google_link_and_click
    expect(page).to have_content("Your account is not active")

    # Can still view profile
    click_on(user.name)
    click_on("Profile")
    expect(page).to have_content("Edit Profile")

    # Can still view accounts
    click_on(user.name)
    click_on("Account")
    expect(page).to have_content("Your Account")
  end
end
