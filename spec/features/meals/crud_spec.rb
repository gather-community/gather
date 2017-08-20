require "rails_helper"

feature "meal crud", js: true do
  let!(:users) { create_list(:user, 2) }
  let!(:location) { create(:resource, name: "Dining Room", abbrv: "DR", meal_hostable: true) }
  let!(:formula) { create(:meal_formula, is_default: true) }
  let!(:meals) { create_list(:meal, 5, formula: formula, resources: [location]) }
  let!(:meal) { meals.first }

  around do |example|
    with_user_home_subdomain(actor) { example.run }
  end

  before do
    login_as(actor, scope: :user)
  end

  context "as meals coordinator" do
    let!(:actor) { create(:meals_coordinator) }

    scenario do
      test_index

      # Create with no menu
      click_on("Create Meal")
      select2(location.name, from: ".meal_resource_ids", type: :inline)
      select2(users[0].name, from: "#meal_head_cook_assign_attributes_user_id")
      select2(users[1].name, from: "#meal_asst_cook_assigns_attributes_0_user_id")
      click_on("Create Meal")
      expect_success

      find("tr", text: users[0].name).find("a", text: "[No Title]").click
      click_link("Edit")
      fill_in_menu

      # Show
      find("a", text: "Southern Beans").click
      expect(page).to have_content("Southern Beans and Rice")
      expect(page).to have_content("Chocolate")

      summary_close_reopen

      # Delete
      find("a", text: "Southern Beans").click
      click_link("Edit")
      click_on("Delete Meal")
      expect_success
      expect(page).not_to have_content("Southern Beans and Rice")
    end
  end

  context "as head cook" do
    let!(:actor) { meal.head_cook }

    scenario do
      test_index
      expect(page).not_to have_content("Create Meal")

      # Update to add menu
      find("tr", text: actor.name).find("a", text: "[No Title]").click
      click_link("Edit")
      expect(page).not_to have_content("Delete Meal")
      fill_in_menu

      # Show
      find("a", text: "Southern Beans").click
      expect(page).to have_content("Southern Beans and Rice")
      expect(page).to have_content("Chocolate")

      summary_close_reopen
    end
  end

  context "as regular user" do
    let!(:actor) { create(:user) }

    scenario do
      test_index
      expect(page).not_to have_content("Create Meal")

      # Update to change assignment
      find("tr", text: meals[4].head_cook.name).find("a", text: "[No Title]").click
      click_link("Edit")
      expect(page).not_to have_content("Delete Meal")
      select2(actor.name, from: "#meal_asst_cook_assigns_attributes_0_user_id")
      click_on("Update Meal")
      expect_success

      # Show
      find("tr", text: meals[4].head_cook.name).find("a", text: "[No Title]").click
      expect(page).to have_css("#meal-menu", text: actor.name)

      # Summary
      click_link("Summary")
      expect(page).to have_content("This meal will require")
      expect(page).to have_css("#meal-menu", text: actor.name)
      expect(page).not_to have_css("a", text: "Close")
    end
  end

  def test_index
    visit("/meals")
    expect(page).to have_css("tr", text: meals[0].head_cook.name)
    expect(page).to have_css("tr", text: meals[4].head_cook.name)
  end

  def fill_in_menu
    fill_in("Title", with: "Southern Beans and Rice")
    fill_in("Entrees", with: "Beans, rice, sausage")
    fill_in("Side", with: "Collards")
    fill_in("Kids", with: "Mac and cheese")
    fill_in("Dessert", with: "Chocolate")
    fill_in("Notes", with: "Partially organic")
    check("Dairy")
    click_on("Update Meal")
    expect_success
  end

  def summary_close_reopen
    # Summary
    click_link("Summary")
    expect(page).to have_content("This meal will require")
    expect(page).to have_content("Southern Beans and Rice")

    # Close/reopen
    click_link("Close")
    expect_success
    find("a", text: "Southern Beans").click
    click_link("Reopen")
    expect_success
  end
end
