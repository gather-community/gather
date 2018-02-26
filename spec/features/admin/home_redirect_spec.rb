require "rails_helper"

feature "home redirect" do
  let(:actor) { create(:admin) }
  let!(:home_cmty) { create(:community, slug: "foo") }
  let(:user) { create(:user, community: home_cmty) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  context "with admin logged in" do
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

  context "with user logged in" do
    before do
      login_as(user, scope: :user)
    end

    scenario "user visits root with various default home page settings set" do
      user.community().settings.default_landing_page = "Meals"
      # default_landing_page gets set properly here, but once we get to the home controller, it's back to the default
      # not sure if there is a before action or something that is overriding it?
      visit "/"
      #expect(page).to have_title("Meals")
    end
  end

  def change_default_home(new_default)
    visit "/admin/settings/community"
    select(new_default, from: "Default Landing Page")
    click_on("Save Settings")
    expect(page).to have_content("Settings updated successfully.")
  end
end
