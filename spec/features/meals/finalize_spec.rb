# frozen_string_literal: true

require "rails_helper"

feature "finalize meal", js: true do
  let!(:actor) { create(:admin) }
  let!(:meal) { create(:meal, :with_menu, served_at: Time.current - 3.days) }
  let!(:signups) { create_list(:signup, 3, meal: meal, adult_veg: 1) }
  let!(:late_add) { create(:household) }

  around do |example|
    with_user_home_subdomain(actor) { example.run }
  end

  before do
    meal.close!
    login_as(actor, scope: :user)
  end

  scenario "happy path" do
    visit new_meal_finalize_path(meal)
    click_link("Add Household")

    # Zero out first household
    all("select[id$=_quantity]").first.select("0")

    # Add a new household
    select2(late_add.name, from: all("select[id$=_household_id]").last)

    # Fill in expenses
    fill_in("Ingredient Cost", with: "100")
    fill_in("Pantry Cost", with: "10")
    choose("Balance Credit")
    click_button("Continue")

    # Go to finalize screen
    expect(page).to have_content("meal has not been finalized yet")
    click_button("Go Back")

    # Go back and add 4 more diners to the late add
    expect(page).to have_content("was not finalized")
    all("select[id$=_quantity]").last.select("5")
    click_button("Continue")

    click_button("Confirm")
    expect(page).to have_content("finalized successfully")

    # Go to meal page to check finalized icon in title and signups correct
    visit meal_path(meal)
    expect(page).to have_css("h1 i.fa-certificate")
    expect(page).to have_content("#{late_add.name} (5)")
    expect(page).to have_content("#{signups[1].household_name} (1)")
    expect(page).not_to have_content(signups[0].household_name)

    # Go to accounts page and ensure correct accounts created
    visit accounts_path
    expect(page).to have_title("Accounts")
    expect(page).to have_content(signups[1].household_name)
    expect(page).to have_content(late_add.name)
    expect(page).not_to have_content(signups[0].household_name)
  end
end
