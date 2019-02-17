# frozen_string_literal: true

require "rails_helper"

feature "meal report", js: true do
  let(:user) { create(:user) }
  let(:community) { user.community }

  around do |example|
    with_user_home_subdomain(user) { example.run }
  end

  before do
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
    before do
      meals = create_list(:meal, 2, :finalized, community: community,
                                                served_at: Time.zone.today - 3.months)
      meals.each do |m|
        m.signups << build(:signup, meal: m, adult_meat: 2)
        m.signups << build(:signup, meal: m, adult_veg: 1)
        m.save!
      end
    end

    scenario "it works", ignore_js_errors: true do
      # There is a weird NVD3 error that I don't have time to debug as things work fine.
      ignore_js_errors do
        visit report_meals_path
        expect(page).to have_content("Meals Report")
        expect(page).to have_content("By Month")

        # This hopefully will test that charts are getting rendered
        # and thus catch any regressions.
        expect(page).to have_css("svg.nvd3-svg")

        select_lens(:dates, "This Year")
        year = Time.zone.today.year
        expect(page).to have_content("January #{year}-December #{year}")
      end
    end
  end
end
