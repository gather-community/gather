# frozen_string_literal: true

require "rails_helper"

describe "meal report", js: true do
  let(:user) { create(:user) }
  let(:community) { user.community }
  let(:formula) do
    create(:meal_formula, parts_attrs: [
      {type: "Adult", share: "100%", portion: 1},
      {type: "Teen", share: "75%", portion: 0.75}
    ])
  end

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  context "with no data" do
    scenario "it shows no data message" do
      visit report_meals_path
      expect(page).to have_content("Meals Report")
      expect(page).to have_content("No matching meal data found")
    end
  end

  context "with data" do
    around do |example|
      Timecop.freeze("2019-11-08 12:00") { example.run }
    end

    before do
      meals = create_list(:meal, 2, :finalized, community: community, formula: formula,
                                                served_at: Time.zone.today - 3.months)
      meals.each do |m|
        m.signups << build(:meal_signup, meal: m, diner_counts: [2, 0])
        m.signups << build(:meal_signup, meal: m, diner_counts: [0, 1])
        m.save!
      end
    end

    scenario "it works" do
      visit report_meals_path
      expect(page).to have_content("Meals Report")
      expect(page).to have_content("By Month")

      # This hopefully will test that charts are getting rendered
      # and thus catch any regressions.
      expect(page).to have_css("svg.nvd3-svg")

      select_lens(:dates, "2019")
      expect(page).to have_content("August 2019 - November 2019")
    end
  end
end
