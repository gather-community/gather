# frozen_string_literal: true

require "rails_helper"

describe "meals" do
  let(:actor) { create(:user) }
  let(:cmty) { actor.community }
  let(:friend_cmty) { create(:community) }
  let(:other_cmty) { with_tenant(create(:cluster)) { create(:community) } }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with meals" do
    let!(:own_meals) { create_list(:meal, 3, community: cmty) }
    let!(:friend_meals) do
      create_list(:meal, 2, community: friend_cmty,
                            communities: [cmty, friend_cmty])
    end
    let!(:other_meal) { create(:meal, :with_menu, community: other_cmty, title: "Flapjacks") }

    scenario "index" do
      visit "/meals?community=all"
      expect(page).not_to have_content("Flapjacks")
      expect(page).to have_css("table.index tbody tr", count: 5)
    end
  end

  context "with no meals, calendars, or formulas" do
    scenario "index" do
      visit "/meals?community=all"
      expect(page).to have_content("No meals found")
    end

    context "with admin" do
      let(:actor) { create(:admin) }

      scenario "create" do
        visit "/meals/new"
        expect(page).to have_content("Before you can create a meal")
        expect(page).not_to have_content("Date/Time")
      end
    end
  end
end
