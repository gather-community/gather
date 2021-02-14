# frozen_string_literal: true

require "rails_helper"

describe "finalize meal", js: true do
  let!(:actor) { create(:admin) }
  let!(:meal) { create(:meal, :with_menu, served_at: Time.current - 3.days) }
  let!(:user) { create(:user, first_name: "Bo", last_name: "Liz") }
  let!(:signups) { create_list(:meal_signup, 3, meal: meal, diner_counts: [1]) }
  let!(:late_add) { create(:household) }

  before do
    use_user_subdomain(actor)
    meal.close!
    login_as(actor, scope: :user)
    meal.head_cook.update!(first_name: "Jo", last_name: "Fiz")
  end

  scenario "happy path" do
    visit new_meal_finalize_path(meal)
    click_link("Add Household")

    # Zero out first household
    all("select[id$=_count]").first.select("0")

    # Add a new household
    select2(late_add.name, from: all("select[id$=_household_id]").last)

    # Fill in expenses
    expect(page).to have_content("Reimbursee *\nJo Fiz")
    fill_in("Ingredient Cost", with: "100")
    fill_in("Pantry Reimbursable Cost", with: "10")
    choose("Balance Credit")
    select2("Bo Liz", from: "#meals_meal_cost_attributes_reimbursee_id")
    click_button("Continue")

    # Go to finalize screen
    expect(page).to have_content("meal has not been finalized yet")
    expect(page).to have_content("Reimbursee Bo Liz")
    click_button("Go Back")

    # Go back and add 4 more diners to the late add
    expect(page).to have_content("was not finalized")
    all("select[id$=_count]").last.select("5")
    click_button("Continue")

    click_button("Confirm")
    expect(page).to have_content("finalized successfully")

    # Go to meal page to check finalized icon in title and signups correct
    visit meal_path(meal)
    expect(page).to have_css("h1 i.fa-certificate")
    expect(page).to have_content("#{late_add.name} (5)")
    expect(page).to have_content("#{signups[1].household_name} (1)")
    expect(page).not_to have_content(signups[0].household_name)

    # Go to accounts page and ensure correct accounts are shown as active
    visit accounts_path
    select_lens(:active, "Show Active Only")
    expect(page).to have_title("Accounts")
    expect(page).to have_content(signups[1].household_name)
    expect(page).to have_content(late_add.name)
    expect(page).not_to have_content(signups[0].household_name)
  end
end
