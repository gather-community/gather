require "rails_helper"

feature "inactive user" do
  let(:user) { create(:user, :inactive) }
  let!(:account) { create(:account, household: user.household) }

  around do |example|
    stub_omniauth(google_oauth2: {email: user.google_email}) do
      example.run
    end
  end

  scenario "visiting page as inactive", js: true do
    visit root_path
    expect_valid_sign_in_link_and_click
    expect(page).to have_content("Your account is not active")

    # Can still view profile
    click_on(user.name)
    click_on("Profile")
    expect(page).to have_content("Edit Profile")

    # Can still view accounts
    click_on(user.name)
    click_on("Accounts")
    expect(page).to have_content("Your Account")
  end
end
