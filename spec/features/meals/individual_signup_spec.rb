# frozen_string_literal: true

require "rails_helper"

feature "meal signups", js: true do
  let(:user) { create(:user) }
  let(:formula) { create(:meal_formula, name: "Fmla A", part_shares: [1, 1, 1]) }
  let!(:meal) do
    create(:meal, :with_menu, formula: formula, title: "Burgers", served_at: Time.current + 7.days)
  end

  around do |example|
    with_user_home_subdomain(user) { example.run }
  end

  before do
    login_as(user, scope: :user)
  end

  scenario "signup for meal, fix validation error, submit again" do
    visit meals_path
    click_link("Burgers")
    click_button("Sign Up")
    all("select[id$=_count]")[0].select(0)
    click_button("Save")

    # Fix validation error
    expect(page).to have_content("You must sign up at least one person")
    all("select[id$=_count]")[0].select("2")
    all("select[id$=_type_id]")[0].select("Fmla A Type 2")
    click_link("Add Item")
    all("select[id$=_count]")[1].select("1")
    all("select[id$=_type_id]")[1].select("Fmla A Type 1")
    fill_in("Comments", with: "Extra tasty please")
    click_button("Save")

    # Edit existing
    click_link("Burgers")
    all("select[id$=_count]")[0].select("3")
    click_button("Save")

    # Read-only mode
    meal.close!
    click_link("Burgers")
    expect(page).to have_content("3 Fmla A Type 1")
    expect(page).to have_content("2 Fmla A Type 2")
    expect(page).to have_content('"Extra tasty please"')
  end

  context "with existing signup" do
    let!(:signup) { create(:meal_signup, meal: meal, household: user.household, diner_counts: [4, 3]) }

    scenario "edit, then unsignup" do
      visit(meal_path(meal))
      all("select[id$=_count]")[0].select("0")
      all("select[id$=_count]")[1].select("0")
      click_button("Save")
      expect(page).to have_css("td", text: "Sign Up") # Signed up column
      click_link("Burgers")
      expect(page).to have_css("button.btn-primary", text: "Sign Up")
    end
  end

  context "with previous signup under current formula" do
    let!(:older_meal) { create(:meal, formula: formula, served_at: Time.current - 20.days) }
    let!(:older_signup) { create(:meal_signup, meal: older_meal, household: user.household, adult_meat: 3) }
    let!(:old_meal) { create(:meal, formula: formula, served_at: Time.current - 10.days) }
    let!(:old_signup) do
      create(:meal_signup, meal: old_meal, household: user.household, diner_counts: [4, 3])
    end

    scenario "same items and quantites should be copied" do
      visit(meal_path(meal))
      click_button("Sign Up")
      expect(page).to have_select(all("select[id$=_count]")[0][:id], selected: "4")
      expect(page).to have_select(all("select[id$=_type_id]")[0][:id], selected: "Fmla A Type 1")
      expect(page).to have_select(all("select[id$=_count]")[1][:id], selected: "3")
      expect(page).to have_select(all("select[id$=_type_id]")[1][:id], selected: "Fmla A Type 2")
    end
  end
end
