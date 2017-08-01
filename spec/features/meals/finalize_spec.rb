require "rails_helper"

feature "finalize meal", js: true do
  let!(:actor) { create(:admin) }
  let!(:formula) { create(:meals_formula) }
  let!(:meal) { create(:meal, :with_menu, served_at: Time.now - 3.days) }
  let!(:signups) { create_list(:signup, 3, meal: meal, adult_veg: 1) }
  let!(:late_add) { create(:household) }

  around do |example|
    with_user_home_subdomain(actor) { example.run }
  end

  before do
    login_as(actor, scope: :user)
    meal.close!
  end

  scenario "zero out row, add row, delete row, continue, modify, finish" do
    visit new_meal_finalize_path(meal)
    all("select[id$=_adult_veg]")[0].select("")
    click_link("Add Signup")
    select2(late_add.name, from: find("select[id$=_household_id]")[:id])
    all("select[id$=_adult_veg]")[3].select("5")
    all(".fa-trash")[1].click
    fill_in("Ingredient Cost", with: "100")
    fill_in("Pantry Cost", with: "10")
    choose("Balance Credit")
    click_button("Continue")

    # Go to finalize screen
    expect(page).to have_content("meal has not been finalized yet")
    click_button("Cancel/Modify")

    # Go back and add 4 more diners to the late add
    expect(page).to have_content("was not finalized")
    all("select[id$=_adult_meat]")[0].select("4")
    click_button("Continue")

    click_button("Confirm")
    expect(page).to have_content("finalized successfully")

    # Go to meal page to check finalized icon in title and signups correct
    visit meal_path(meal)
    expect(page).to have_css("h1 i.fa-certificate")
    expect(page).to have_content("#{late_add.name} (9)")
    expect(page).to have_content("#{signups[2].household_name} (1)")
    expect(page).not_to have_content(signups[1].household_name)
    expect(page).not_to have_content(signups[0].household_name)

    # Go to accounts page and ensure correct accounts created
    visit accounts_path
    expect(page).to have_title("Accounts")
    expect(page).not_to have_content(signups[0].household_name)
    expect(page).not_to have_content(signups[1].household_name)
    expect(page).to have_content(signups[2].household_name)
    expect(page).to have_content(late_add.name)
  end
end
