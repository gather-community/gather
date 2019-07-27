# frozen_string_literal: true

require "rails_helper"

feature "meal signups form", js: true do
  let(:actor) { create(:meals_coordinator) }
  let!(:meal) { create(:meal, served_at: Time.current + 7.days) }
  let!(:households) { create_list(:household, 2) }

  around do |example|
    with_user_home_subdomain(actor) { example.run }
  end

  before do
    login_as(actor, scope: :user)
  end

  scenario do
    # Try to submit duplicate signups
    visit edit_meal_path(meal)
    click_link("Edit Signups")
    enter_signup(household: households[0], quantities: {"Adult (Meat)": 2, "Adult (Veg)": 3})
    enter_signup(household: households[0], quantities: {"Teen (Veg)": 4})
    click_button("Save")
    expect(page).to have_content("Has already been taken")

    # Spot check one line
    expect(page).to have_select(all("select[id$=_count]")[2][:id], selected: "4")
    expect(page).to have_select(all("select[id$=_type_id]")[2][:id], selected: "Teen (Veg)")

    # Fix and submit
    select2(households[1].name, from: all("select[id$=_household_id]")[1])
    click_button("Save")

    # Remove a signup by zeroing out, and change the other one.
    visit edit_meal_path(meal)
    click_link("Edit Signups")
    enter_signup(index: 0, quantities: {"Adult (Meat)": 0, "Adult (Veg)": 0})
    enter_signup(index: 1, quantities: {"Teen (Meat)": 6})
    click_button("Save")
    expect_success

    # Check only one signup remains
    visit edit_meal_path(meal)
    click_link("Edit Signups")
    expect(all(".meals_meal_signups_signup").size).to eq(1)
    expect(page).to have_select(all("select[id$=_count]")[0][:id], selected: "6")
    expect(page).to have_select(all("select[id$=_type_id]")[0][:id], selected: "Teen (Meat)")
  end

  def enter_signup(quantities:, household: nil, index: nil)
    if index.nil? # This means add a new one
      index = all(".meals_meal_signups_signup").size
      click_link("Add Household")
    end
    within(all(".meals_meal_signups_signup")[index]) do
      select2(household.name, from: first("select[id$=_household_id]")) unless household.nil?
      quantities.each_with_index do |pair, i|
        click_link("Add Item") if all("select[id$=_count]").size <= i
        all("select[id$=_count]")[i].select(pair[1].to_s)
        all("select[id$=_type_id]")[i].select(pair[0])
      end
    end
  end
end
