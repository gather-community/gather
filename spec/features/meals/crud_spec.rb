require "rails_helper"

feature "meal crud", js: true do
  let!(:actor) { create(:admin) }
  let!(:users) { create_list(:user, 2) }
  let!(:location) { create(:resource, name: "Dining Room", abbrv: "DR", meal_hostable: true) }
  let!(:formula) { create(:meal_formula, is_default: true) }
  let!(:meals) { create_list(:meal, 5, :with_menu, formula: formula, resources: [location]) }

  around do |example|
    with_user_home_subdomain(actor) { example.run }
  end

  before do
    login_as(actor, scope: :user)
  end

  scenario do
    # Index
    visit("/meals")
    expect(page).to have_content(meals[0].title)
    expect(page).to have_content(meals[4].title)

    # Create with no menu
    click_on("Create Meal")
    select2(location.name, from: ".meal_resource_ids", type: :inline)
    select2(users[0].name, from: "#meal_head_cook_assign_attributes_user_id")
    select2(users[1].name, from: "#meal_asst_cook_assigns_attributes_0_user_id")
    click_on("Create Meal")
    expect_success

    # Update to add menu
    find("tr", text: users[0].name).find("a", text: "[No Title]").click
    click_link("Edit")
    fill_in("Title", with: "Southern Beans and Rice")
    fill_in("Entrees", with: "Beans, rice, sausage")
    fill_in("Side", with: "Collards")
    fill_in("Kids", with: "Mac and cheese")
    fill_in("Dessert", with: "Chocolate")
    fill_in("Notes", with: "Partially organic")
    check("Dairy")
    click_on("Update Meal")
    expect_success

    # Show
    find("a", text: "Southern Beans").click
    expect(page).to have_content(users[0].name)
    expect(page).to have_content(users[1].name)
    expect(page).to have_content("Southern Beans and Rice")
    expect(page).to have_content("Chocolate")

    # Summary
    click_link("Summary")
    expect(page).to have_content("This meal will require")
    expect(page).to have_content(users[0].name)

    # Close/reopen
    click_link("Close")
    expect_success
    find("a", text: "Southern Beans").click
    click_link("Reopen")
    expect_success

    # Delete
    find("a", text: "Southern Beans").click
    click_link("Edit")
    click_on("Delete Meal")
    expect_success
    expect(page).not_to have_content("Southern Beans and Rice")




  end
end
