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

    ["Meals", "Directory", "Reservations", "Wiki"].each { |new_default|
      change_default_home(new_default)
      visit "/"
      expect(page).to have_title(new_default)
    }
  end
end

def change_default_home(new_default)
    visit "/admin/settings/community"
    select(new_default, from: "Default landing page")
    click_on("Save Settings")
    expect(page).to have_content("Settings updated successfully.")
end

#TODO - create feature to test moving the default home page and then logging out/in
#feature "home redirect2" do
#  let(:actor) { create(:admin) }
#
#  around { |ex| with_user_home_subdomain(actor) { ex.run } }
#
#  before do
#  end
#
#  scenario "admin changes default home and logs out then logs in" do
#    puts page.body
#    login_as(actor, scope: :user)
#    expect(page).to have_title("Directory")
#    visit "/admin/settings/community"
#    select("Reservations", from: "Default landing page")
#    click_on("Save Settings")
#    expect(page).to have_content("Settings updated successfully.")
#    log_out(actor)
#    login_as(actor, scope: :user)
#    expect(page).to have_title("Reservations")
#  end
#end
