# frozen_string_literal: true

require "rails_helper"

describe "finalize meal", js: true do
  let!(:actor) { create(:admin) }
  let!(:meal) { create(:meal, :with_menu, title: "Super yumz", served_at: Time.current - 3.days) }
  let!(:user) { create(:user, first_name: "Bo", last_name: "Liz") }
  let!(:signups) { create_list(:meal_signup, 3, meal: meal, diner_counts: [1]) }
  let!(:late_add) { create(:household) }

  before do
    use_user_subdomain(actor)
    meal.close!
    login_as(actor, scope: :user)
    meal.head_cook.update!(first_name: "Jo", last_name: "Fiz")
    Defaults.community.update!(settings: {billing: {paypal_reimbursement: true}})
  end

  scenario "without editing expenses in meal" do
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
    expect(page).to have_content("Ingredient Cost $100.00")
    expect(page).to have_content("Pantry Reimbursable Cost $10.00")
    click_button("Go Back")

    # Go back and add 4 more diners to the late add
    expect(page).to have_content("was not finalized")
    expect(page).to have_field("Ingredient Cost", with: "100.00")
    expect(page).to have_field("Pantry Reimbursable Cost", with: "10.00")
    expect(page).to have_select("Reimbursee", selected: "Bo Liz")
    expect(find("#meals_meal_cost_attributes_payment_method_credit")).to be_checked
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

    # Unfinalize
    visit meal_path(meal)
    accept_confirm { click_on("Unfinalize") }
    expect(page).to have_content("Meal unfinalized successfully")
  end

  scenario "with editing expenses in meal" do
    visit(edit_meals_meal_path(meal))

    # Zero out first household
    all("select[id$=_count]").first.select("0")

    fill_in("Ingredient Cost", with: "100")
    fill_in("Pantry Reimbursable Cost", with: "10")
    select2("Bo Liz", from: "#meals_meal_cost_attributes_reimbursee_id")
    choose("PayPal")
    click_button("Save")

    visit(meals_meal_path(meal))
    expect(page).to have_content("Super yumz", wait: 10)
    click_link("Finalize")

    # Add a new household
    click_link("Add Household")
    select2(late_add.name, from: all("select[id$=_household_id]").last)

    # Ensure expense data still there
    expect(page).to have_field("Ingredient Cost", with: "100.00")
    expect(page).to have_field("Pantry Reimbursable Cost", with: "10.00")
    expect(page).to have_select("Reimbursee", selected: "Bo Liz")
    expect(find("#meals_meal_cost_attributes_payment_method_paypal")).to be_checked

    click_button("Continue")

    # Go to finalize screen
    expect(page).to have_content("meal has not been finalized yet")
    expect(page).to have_content("Reimbursee Bo Liz")
    expect(page).to have_content("Ingredient Cost $100.00")
    expect(page).to have_content("Pantry Reimbursable Cost $10.00")
    click_button("Go Back")

    # Go back and add 4 more diners to the late add
    expect(page).to have_content("was not finalized")
    expect(page).to have_field("Ingredient Cost", with: "100.00")
    expect(page).to have_field("Pantry Reimbursable Cost", with: "10.00")
    expect(page).to have_select("Reimbursee", selected: "Bo Liz")
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
