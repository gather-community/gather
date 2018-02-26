require "rails_helper"

feature "home redirect" do
  let(:actor) { create(:admin) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  scenario "admin changes default home and visits root url" do
    visit "/"
    expect(page).to have_title("Directory")

    %w[Meals Directory Reservations Wiki].each do |new_default|
      change_default_home(new_default)
      visit "/"
      expect(page).to have_title(new_default)
    end
  end
end

def change_default_home(new_default)
    visit "/admin/settings/community"
    select(new_default, from: "Default Landing Page")
    click_on("Save Settings")
    expect(page).to have_content("Settings updated successfully.")
end
