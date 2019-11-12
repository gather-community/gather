# frozen_string_literal: true

require "rails_helper"

describe "formulas", js: true do
  let(:actor) { create(:meals_coordinator) }
  let!(:head_cook_role) { create(:meal_role, :head_cook) }
  let!(:other_role) { create(:meal_role, title: "Stumbler") }
  let!(:formulas) { create_list(:meal_formula, 2, roles: [head_cook_role]) }
  let!(:adult_type) { create(:meal_type, name: "Adult") }

  before do
    use_user_subdomain(actor)
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
    select2("Stumbler", from: "#meals_formula_role_ids", multiple: true)
    find("#meals_formula_meal_calc_type").select("Fixed")
    expect(page).to have_content("Add each meal type, its price")
    click_link("Add Meal Type")
    within(all(".meals_formula_parts .nested-fields")[0]) do
      select2("Adults", from: "select[id$=_type_id]")
      fill_in("Price/Share", with: "2")
    end
    click_link("Add Meal Type")
    within(all(".meals_formula_parts .nested-fields")[1]) do
      select2("Newtype", from: "select[id$=_type_id]")
      fill_in("Price/Share", with: "$2.50")
    end
    find("#meals_formula_pantry_calc_type").select("Percentage")
    fill_in("Pantry Fee", with: "10.2%")
    click_button("Save")
    expect_success

    click_link("Free Meal")
    expect(page).to have_content("Head Cook, Stumbler")
    expect(page).to have_content("Adults")
    expect(page).to have_content("Newtype")
    expect(page).to have_content("$2.00")
    expect(page).to have_content("10.2%")
    click_on("Edit")

    within(all(".meals_formula_parts .nested-fields")[1]) do
      fill_in("Price/Share", with: "$2.60")
    end
    within(all(".meals_formula_parts .nested-fields")[0]) do
      click_delete_link
    end
    click_button("Save")
    expect_success

    click_link("Free Meal")
    expect(page).not_to have_content("$2.50")
    expect(page).not_to have_content("$2.00")
    expect(page).not_to have_content("Adults")
    expect(page).to have_content("$2.60")
  end

  scenario "deactivate/activate/delete" do
    visit(edit_meals_formula_path(formulas.first))
    accept_confirm { click_on("Deactivate") }
    expect_success

    click_link("Edit")
    click_link("reactivate it")
    expect_success

    expect(page).not_to have_content("#{formulas.first.name} (Inactive)")
    click_link("Edit")
    accept_confirm { click_on("Delete") }
    expect_success

    expect(page).not_to have_content(formulas.first.name)
  end
end
