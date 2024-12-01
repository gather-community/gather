# frozen_string_literal: true

require "rails_helper"

describe "meal create, show, update, delete", js: true do
  let!(:users) { create_list(:user, 2) }
  let!(:reimbursee) { create(:user, first_name: "Jo", last_name: "Fiz") }
  let!(:location) { create(:calendar, name: "Dining Room", abbrv: "DR", meal_hostable: true) }
  let!(:formula) { create(:meal_formula, :with_two_roles, name: "Formula 1", is_default: true) }
  let!(:no_ac_formula) { create(:meal_formula, name: "Formula 2") }
  let(:hc_role) { formula.roles[0] }
  let(:ac_role) { formula.roles[1] }
  let!(:meals) { create_list(:meal, 5, formula: formula, calendars: [location]) }
  let!(:meal) { meals.first }

  # This is to make sure the community checkboxes show.
  let!(:community2) { create(:community, name: "Funtown") }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "as meals coordinator" do
    let!(:actor) { create(:meals_coordinator) }

    scenario do
      visit(meals_path)

      # Create with no menu
      find("button.dropdown-toggle").click
      click_on("Create Meal")
      fill_in("Capacity", with: "")
      click_on("Save")

      expect(page).to have_content("can't be blank")
      fill_in("Capacity", with: "50")
      select2(location.name, from: "#meals_meal_calendar_ids", multiple: true)

      # Formula change changes worker roles
      check("Funtown")
      select("Formula 2", from: "Formula")
      expect(page).not_to have_content("Assistant Cook")
      select("Formula 1", from: "Formula")
      expect(page).to have_content("Assistant Cook")

      select_worker(users[0].name, role: hc_role)
      add_worker_field(role: ac_role)
      select_worker(users[1].name, role: ac_role)
      click_button("Save")
      expect_success

      find("tr", text: users[0].name).find("a", text: "[No Menu]").click
      click_link("Edit")
      expect(page).to have_field("Funtown", checked: true)
      fill_in_menu

      # Show
      find("a", text: "Southern Beans").click
      expect(page).to have_content("Head Cook #{users[0].name}")
      expect(page).to have_content("Southern Beans and Rice")
      expect(page).to have_content("Chocolate")

      # Remove and change head cook (to ensure the destroy flag gets unset once new person selected)
      # These two blocks test the allow_clear option for the nested_fields code.
      click_link("Edit")
      select_worker(:clear, role: hc_role)
      select_worker(users[1].name, role: hc_role)
      click_button("Save")
      expect_success
      find("a", text: "Southern Beans").click
      expect(page).to have_content("Head Cook #{users[1].name}")

      # Remove head cook
      click_link("Edit")
      select_worker(:clear, role: hc_role)
      click_button("Save") # First click clears the focus
      click_button("Save")
      expect_success
      find("a", text: "Southern Beans").click
      expect(page).not_to have_content("Head Cook")

      summary_close_reopen

      # Delete
      find("a", text: "Southern Beans").click
      click_link("Edit")
      accept_confirm { click_on("Delete") }
      expect_success
      expect(page).not_to have_content("Southern Beans and Rice")
    end
  end

  context "as head cook" do
    let!(:actor) { meal.head_cook }

    scenario do
      visit(meals_path)
      expect(page).not_to have_content("Create Meal")

      # Update to add menu
      find("table.index tr", text: actor.name).find("a", text: "[No Menu]").click
      click_link("Edit")
      expect(page).not_to have_field("Funtown")
      expect(page).not_to have_content("Delete Meal")
      fill_in_menu

      # Update to add expenses
      click_link("Southern Beans")
      click_link("Edit")
      fill_in("Ingredient Cost", with: "125.66")
      fill_in("Pantry Reimbursable Cost", with: "12.30")
      accept_alert { select2("Jo Fiz", from: "#meals_meal_cost_attributes_reimbursee_id") }
      choose("Balance Credit")
      click_button("Save")
      expect_success
      click_link("Southern Beans")
      click_link("Edit")
      expect(page).to have_field("Ingredient Cost", with: "125.66")
      expect(page).to have_content("Reimbursee *\nJo Fiz")
      click_button("Save")

      # Show
      click_link("Southern Beans")
      expect(page).to have_content("Southern Beans and Rice")
      expect(page).to have_content("Chocolate")
      expect(page).to have_content("Shellfish")

      summary_close_reopen
    end
  end

  context "as regular user" do
    let!(:actor) { create(:user) }

    shared_examples_for "allows show, summary, and edit to workers" do
      scenario do
        visit(meals_path)
        expect(page).not_to have_content("Create Meal")

        # Update to change assignment
        find("tr", text: meals[4].head_cook.name).find("a", text: meals[4].title || "[No Menu]").click
        click_link("Edit")
        expect(page).not_to have_content("Delete Meal")
        add_worker_field(role: ac_role)
        message = accept_confirm { select_worker(actor.name, role: ac_role) }
        expect(message).to match(/If you change meal workers/)

        expect do
          click_button("Save")
          expect_success
        end.to change { ActionMailer::Base.deliveries.size }.by(1)
        expect(ActionMailer::Base.deliveries.last.subject).to eq("Meal Job Assignment Change Notice")

        # Show
        find("tr", text: meals[4].head_cook.name).find("a", text: meals[4].title || "[No Menu]").click
        expect(page).to have_css("#meal-menu", text: actor.name)

        # Summary
        click_link("Summary")
        expect(page).to have_content(/This meal has.+and will require/)
        expect(page).to have_css("#meal-menu", text: actor.name)
        expect(page).not_to have_css("a", text: "Close")
      end
    end

    context "without menu" do
      it_behaves_like "allows show, summary, and edit to workers"
    end

    context "with menu" do
      before do
        meals[4].update!(title: "Foo", entrees: "Foo + eggs", allergens: ["Eggs"])
      end

      it_behaves_like "allows show, summary, and edit to workers"
    end
  end

  def worker_div_selector(role:)
    %(#assignment-fields div[data-role-id="#{role.id}"])
  end

  def add_worker_field(role:)
    find("#{worker_div_selector(role: role)} a.add_fields").click
  end

  def select_worker(user, role:)
    select = all("#{worker_div_selector(role: role)} select")[0]
    select2(user, from: select)
  end

  def fill_in_menu
    fill_in("Title", with: "Southern Beans and Rice")
    fill_in("Entrees", with: "Beans, rice, sausage")
    fill_in("Side", with: "Collards")
    fill_in("Kids", with: "Mac and cheese")
    fill_in("Dessert", with: "Chocolate")
    fill_in("Notes", with: "Partially organic")
    check("Shellfish")
    click_button("Save")
    expect_success
  end

  def summary_close_reopen
    # Summary
    click_link("Summary")
    expect(page).to have_content(/This meal has.+and will require/)
    expect(page).to have_content("Southern Beans and Rice")
    page.driver.go_back

    # Close/reopen
    accept_confirm { click_link("Close") }
    expect_success
    click_link("Southern Beans")
    accept_confirm { click_link("Reopen") }
    expect_success
  end
end
