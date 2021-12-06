# frozen_string_literal: true

require "rails_helper"

describe "household worker form", js: true do
  let!(:user) { create(:user) }
  let!(:other_user) { create(:user, household: user.household) }
  let(:formula) { create(:meal_formula, :with_two_roles, name: "Fmla A") }
  let!(:meal) do
    create(:meal, formula: formula, head_cook: false)
  end

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  context "with no existing meal jobs in household" do
    context "with unfilled jobs" do
      scenario do
        visit(meal_path(meal))
        expect(page).not_to have_content("person from your household is helping")
        expect(page).to have_content("This meal still needs 2 workers")

        click_on("Help Out")
        select(user.name, from: "Head Cook")
        click_on("Save")

        expect(page).to have_content("1 person from your household is helping")
        expect(page).to have_content("This meal still needs 1 worker")

        click_on("Help Out")
        select(other_user.name, from: "Assistant Cook")
        click_on("Save")

        expect(page).to have_content("2 people from your household are helping")
        expect(page).not_to have_content("This meal still needs")
      end
    end

    context "with all jobs filled" do
      let!(:assign1) { create(:meal_assignment, meal: meal, role: formula.head_cook_role) }
      let!(:assign2) { create(:meal_assignment, meal: meal, role: formula.roles[1]) }

      scenario do
        visit(meal_path(meal))
        expect(page).not_to have_content("person from your household is helping")
        expect(page).not_to have_content("This meal still needs")
        expect(page).to have_content("This meal doesn't need any more workers")
      end
    end
  end

  context "with existing meal jobs in household" do
    let(:other_user) { create(:user, household: user.household) }
    let!(:assign) { create(:meal_assignment, meal: meal, role: formula.head_cook_role, user: other_user) }

    scenario do
      visit(meal_path(meal))
      expect(page).to have_content("person from your household is helping")
      expect(page).to have_content("#{other_user.name} - Head Cook")
      expect(page).to have_content("This meal still needs")

      within(find("#household-worker-info")) do
        accept_confirm { find("a.delete-assign").click }
      end

      expect(page).not_to have_content("person from your household is helping")
      expect(page).not_to have_content("#{other_user.name} - Head Cook")
    end
  end
end
