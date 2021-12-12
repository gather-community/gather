# frozen_string_literal: true

require "rails_helper"

describe Meals::AssignmentPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:head_cook_role) { create(:meal_role, :head_cook) }
    let(:formula) { create(:meal_formula, roles: [head_cook_role]) }
    let(:meal) { create(:meal, formula: formula) }
    let(:assignment) { create(:meal_assignment, meal: meal, user: assigned_user, role: head_cook_role) }

    context "with assigned user in household" do
      let(:assigned_user) { create(:user, household: user.household) }
      let(:actor) { user }

      permissions :destroy? do
        it { is_expected.to permit(actor, assignment) }
      end
    end

    context "with assigned user in different household" do
      let(:assigned_user) { create(:user) }

      context "as regular user" do
        let(:actor) { user }

        permissions :destroy? do
          it { is_expected.not_to permit(actor, assignment) }
        end
      end

      context "as meals coordinator" do
        let(:actor) { meals_coordinator }

        permissions :destroy? do
          it { is_expected.to permit(actor, assignment) }
        end
      end

      context "as admin" do
        let(:actor) { admin }

        permissions :destroy? do
          it { is_expected.to permit(actor, assignment) }
        end
      end
    end
  end
end
