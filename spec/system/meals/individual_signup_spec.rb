# frozen_string_literal: true

require "rails_helper"

describe "meal signups", js: true do
  let(:user) { create(:user) }
  let(:formula) { create(:meal_formula, name: "Fmla A", parts_attrs: [1, 1, 1]) }
  let!(:meal) do
    create(:meal, :with_menu, formula: formula, title: "Burgers", served_at: Time.current + 7.days,
                              capacity: 10)
  end

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  scenario "signup for meal, fix validation error, submit again" do
    visit(meals_path)
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
    expect(page).to have_alert("Signup saved successfully")
    expect(page).not_to have_alert("Signup saved successfully")

    # Edit existing
    all("select[id$=_count]")[0].select("3")
    click_button("Save")
    expect(page).to have_alert("Signup saved successfully")

    # Read-only mode
    meal.close!
    visit(current_path)
    expect(page).to have_content("1 Fmla A Type 1")
    expect(page).to have_content("3 Fmla A Type 2")
    expect(page).to have_content('"Extra tasty please"')
  end

  context "with existing signup" do
    let!(:signup) { create(:meal_signup, meal: meal, household: user.household, diner_counts: [4, 3]) }

    scenario "edit, then unsignup" do
      visit(meal_path(meal))
      all("select[id$=_count]")[0].select("0")
      all("select[id$=_count]")[1].select("0")
      click_button("Save")
      expect(page).to have_content("Signup saved successfully")

      # Sign up button should reappear, indicating signup was destroyed
      visit(meal_path(meal))
      expect(page).to have_css("button.btn-primary", text: "Sign Up")
    end
  end

  context "with click on save and go to next" do
    let!(:meal2) do
      create(:meal, :with_menu, formula: formula, title: "Fries", served_at: Time.current + 8.days)
    end

    scenario do
      visit(meal_path(meal))
      click_on("Sign Up")
      all("select[id$=_count]")[0].select(9)
      click_button("Save & Go To Next Meal")
      expect(page).to have_content("Fries")

      # Ensure choice was persisted
      click_link("Burgers")
      expect(page).to have_select("meals_signup_parts_attributes_0_count", selected: "9")
    end
  end

  context "when meal gets closed right before new signup" do
    scenario do
      visit(meal_path(meal))
      meal.close!
      click_button("Sign Up")
      all("select[id$=_count]")[0].select("2")
      click_button("Save")
      expect(page).to have_alert("Your signup could not be recorded because " \
                                 "the meal is full or no longer open.")
      expect(page).to have_content("You have not signed up for this meal and it is now closed.")
    end
  end

  context "when meal gets closed right before signup change" do
    let!(:signup) { create(:meal_signup, meal: meal, household: user.household, diner_counts: [4, 3]) }

    scenario do
      visit(meal_path(meal))
      meal.close!
      all("select[id$=_count]")[0].select("0")
      all("select[id$=_count]")[1].select("0")
      click_button("Save")
      expect(page).to have_alert("Your signup could not be recorded because " \
                                 "the meal is full or no longer open.")
      expect(page).to have_content("4 Fmla A Type 1")
    end
  end

  context "when meal gets full right before new signup" do
    scenario do
      visit(meal_path(meal))
      create(:meal_signup, meal: meal, diner_counts: [10, 0])
      click_button("Sign Up")
      all("select[id$=_count]")[0].select("2")
      click_button("Save")
      expect(page).to have_alert("Your signup could not be recorded because " \
                                 "the meal is full or no longer open.")
      expect(page).to have_content("You have not signed up for this meal and it is now full.")
    end
  end

  context "with previous signup under current formula" do
    let!(:older_meal) { create(:meal, formula: formula, served_at: Time.current - 20.days) }
    let!(:older_signup) do
      create(:meal_signup, meal: older_meal, household: user.household, diner_counts: [3])
    end
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
