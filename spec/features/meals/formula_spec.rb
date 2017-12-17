require "rails_helper"

feature "formulas", js: true do
  let(:actor) { create(:meals_coordinator) }
  let!(:formulas) { create_list(:meal_formula, 2) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  scenario "index" do
    visit(meals_formulas_path)
    expect(page).to have_title("Meal Formulas")
    expect(page).to have_css("table.index tr", count: 3) # Header plus two rows
  end

  scenario "create, show, and update" do
    visit(meals_formulas_path)
    click_link("Create")
    fill_in("Name", with: "Free Meal")
    check("Default")
    find("#meals_formula_meal_calc_type").select("Fixed")
    expect(page).to have_content("Enter the price diners of each type")
    fill_in("Adult (Meat)", with: "$2.50")
    fill_in("Teen (Meat)", with: "2")
    find("#meals_formula_pantry_calc_type").select("Percentage")
    fill_in("Pantry Fee Amount", with: "10%")
    click_on("Create Formula")
    expect_success

    click_link("Free Meal")
    expect(page).to have_content("$2.00")
    click_on("Edit")
    fill_in("Teen (Meat)", with: "2.99")
    click_on("Update Formula")
    expect_success

    click_link("Free Meal")
    expect(page).to have_content("$2.99")
  end

  scenario "deactivate/activate/delete" do
    visit(edit_meals_formula_path(formulas.first))
    accept_confirm { click_on("Deactivate") }
    expect_success
    click_link("#{formulas.first.name} (Inactive)")
    click_link("Edit")
    click_link("reactivate it")
    expect_success
    expect(page).not_to have_content("#{formulas.first.name} (Inactive)")
    click_link(formulas.first.name)
    click_link("Edit")
    accept_confirm { click_on("Delete") }
    expect_success
    expect(page).not_to have_content(formulas.first.name)
  end
end
