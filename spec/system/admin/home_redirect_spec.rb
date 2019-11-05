require "rails_helper"

describe "home redirect" do

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  context "with admin signed in" do
    let(:actor) { create(:admin) }

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

  context "with user signed in" do
    let(:home_cmty) { create(:community) }
    let(:actor) { create(:user, community: home_cmty) }

    before do
      actor.community.settings.default_landing_page = "meals"
      actor.community.save!
    end

    scenario "user visits root with meals default home page set" do
      visit "/"
      expect(page).to have_title("Meals")
    end
  end

  def change_default_home(new_default)
    visit "/admin/settings/community"
    select(new_default, from: "Default Landing Page")
    click_button("Save")
    expect(page).to have_content("Settings updated successfully.")
  end
end
