# frozen_string_literal: true

require "rails_helper"

describe "meal csv exports", js: true do
  let!(:formula) { create(:meal_formula, is_default: true) }
  let!(:meal) { create(:meal, :with_menu, formula: formula, served_at: "2019-05-15 18:00") }
  let!(:signup) { create(:meal_signup, meal: meal, diner_counts: [2]) }
  let(:community) { Defaults.community }
  let(:year) { meal.served_at.year }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "as meals coordinator" do
    let(:actor) { create(:meals_coordinator) }

    scenario "download meals csv" do
      visit(meals_path)
      click_link("Download Meals as CSV")
      select(year, from: "meals-dates")
      downloads = wait_for_downloads
      expect(downloads.size).to eq(1)
      expect(File.read(downloads.first)).to match(%r{Date/Time,Locations,Formula})
      expect(File.basename(downloads.first))
        .to eq("#{community.slug}-meals-#{year}0101-#{year}1231.csv")
    end

    scenario "download meal signups csv" do
      visit(meals_path)
      click_link("Download Meal Signups as CSV")
      select(year, from: "signups-dates")
      downloads = wait_for_downloads
      expect(downloads.size).to eq(1)
      expect(File.read(downloads.first)).to match(/Meal ID,Meal Date\/Time/)
      expect(File.read(downloads.first)).to match(/#{signup.household_name}/)
      expect(File.basename(downloads.first))
        .to eq("#{community.slug}-meal-signups-#{year}0101-#{year}1231.csv")
    end
  end

  context "as regular user" do
    let(:actor) { create(:user) }

    scenario "export links are not shown" do
      visit(meals_path)
      expect(page).not_to have_link("Download Meals as CSV")
      expect(page).not_to have_link("Download Meal Signups as CSV")
    end
  end
end
