require "rails_helper"

feature "home redirect" do
  let(:actor) { create(:admin) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  scenario "changes default landing page to meals" do
    visit "/"
    expect(page).to have_title("Directory")
    visit "/admin/settings/community"
    select("Meals", from: "Default landing page")
    click_on("Save Settings")
    expect(page).to have_content("Settings updated successfully.")
    visit "/"
    expect(page).to have_title("Meals")
  end
end
