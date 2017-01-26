require "rails_helper"

feature "inactive user" do
  let(:user) { create(:user, :inactive) }

  before do
    login_as(user)
  end

  scenario "logging in as inactive", js: true do
    visit("/")
    expect(page).to have_content("Your account is not active")

    # Can still view profile
    click_on(user.name)
    click_on("Profile")
    expect(page).to have_content("Edit Profile")

    # Can still view accounts
    click_on(user.name)
    click_on("Accounts")
    expect(page).to have_content("Accounts")
  end
end
