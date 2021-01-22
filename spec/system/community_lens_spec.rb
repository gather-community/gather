# frozen_string_literal: true

require "rails_helper"

describe "community lens", js: true do
  let!(:community1) { Defaults.community }
  let!(:community2) { create(:community, name: "Community 2", slug: "community2") }
  let!(:community3) { create(:community, name: "Community 3", slug: "community3") }
  let!(:user) { create(:user, community: community3) }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  context "basic" do
    scenario do
      visit(users_path)
      expect(lens_selected_option(:community).text).to eq("Community 3")
      lens_field(:community).select("Community 2")
      expect(page).to have_echoed_url(%r{\Ahttp://community2\.})
      expect(lens_selected_option(:community).text).to eq("Community 2")
      expect(page).not_to have_css(".lens-bar a.clear")
    end
  end

  context "with all option" do
    scenario do
      visit(meals_path)

      expect_unselected_option(lens_selector(:community), "All Communities")
      lens_field(:community).select("Community 2")

      expect(page).to have_echoed_url(%r{\Ahttp://community2\.})
      expect(lens_selected_option(:community).text).to eq("Community 2")
      expect(page).to have_echoed_url_param("community", "this")
      # Clear button should work for all option mode only
      first(".lens-bar a.clear").click

      expect(page).to have_echoed_url_param("community", "")
      expect_unselected_option(lens_selector(:community), "All Communities")
    end
  end

  context "with no subdomain change" do
    before do
      [community1, community2, community3].each do |c|
        Billing::AccountManager.instance.account_for(household_id: user.household_id, community_id: c.id)
      end
    end

    scenario do
      visit(yours_accounts_path)
      expect(lens_selected_option(:community).text).to eq("Community 3")

      lens_field(:community).select("Community 2")

      expect(page).to have_echoed_url(%r{\Ahttp://community3\.})
      expect(page).to have_echoed_url_param("community", "community2")
      expect(lens_selected_option(:community).text).to eq("Community 2")
      expect(page).not_to have_css(".lens-bar a.clear")
      visit(yours_accounts_path)

      expect(page).to have_echoed_url(yours_accounts_path)
      expect(lens_selected_option(:community).text).to eq("Community 2")
    end
  end
end
