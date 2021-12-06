# frozen_string_literal: true

require "rails_helper"

describe "household worker form", js: true do
  let(:user) { create(:user) }
  let(:formula) { create(:meal_formula, :with_two_roles, name: "Fmla A") }
  let!(:meal) do
    create(:meal, formula: formula, head_cook: false)
  end

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  context "with no existing meal jobs in household" do
    scenario do
      visit(meal_path(meal))
      expect(page).not_to have_content("person from your household is helping")
      expect(page).to have_content("This meal still needs")
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
