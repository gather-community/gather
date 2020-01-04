# frozen_string_literal: true

require "rails_helper"

describe "types", js: true do
  let(:actor) { create(:meals_coordinator) }
  let!(:types) { create_list(:meal_type, 2) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "index" do
    visit(meals_types_path)
    expect(page).to have_title("Meal Types")
    expect(page).to have_css("table.index tr", count: 3) # Header plus two rows
  end

  scenario "create and update" do
    visit(meals_types_path)
    click_link("Create Type")
    fill_in("Name", with: "Extra Large")
    select2("New Category", from: "select[id$=_category]")
    click_button("Save")
    expect_success

    click_link("Create Type")
    fill_in("Name", with: "Large")
    select2("New Category", from: "select[id$=_category]")
    click_button("Save")
    expect_success

    click_link("Extra Large")
    fill_in("Name", with: "Exxtra Large")
    click_button("Save")

    expect_success
    expect(page).to have_content("Exxtra Large")
  end

  scenario "deactivate/activate/delete" do
    visit(edit_meals_type_path(types.first))
    accept_confirm { click_on("Deactivate") }

    expect_success
    click_link("#{types.first.name} (Inactive)")
    click_link("reactivate it")

    expect_success
    expect(page).not_to have_content("#{types.first.name} (Inactive)")
    click_link(types.first.name)

    accept_confirm { click_on("Delete") }

    expect_success
    expect(page).not_to have_content(types.first.name)
  end
end
