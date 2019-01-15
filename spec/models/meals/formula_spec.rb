# frozen_string_literal: true

require "rails_helper"

describe Meals::Formula do
  describe "validation" do
    describe "must_have_head_cook_role" do
      let!(:head_cook_role) { create(:meal_role, :head_cook) }
      let!(:other_role) { create(:meal_role) }

      context "with head cook role assigned" do
        subject(:formula) { build(:meal_formula, role_ids: [head_cook_role.id, other_role.id]) }
        it { is_expected.to be_valid }
      end

      context "with other role only role assigned" do
        subject(:formula) { build(:meal_formula, role_ids: [other_role.id]) }
        it { is_expected.to have_errors(role_ids: "Must include Head Cook") }
      end

      context "with head_cook role assigned but removed" do
        subject(:formula) { create(:meal_formula, role_ids: [head_cook_role.id]) }

        it do
          formula.assign_attributes(role_ids: [other_role.id])
          expect(formula).to have_errors(role_ids: "Must include Head Cook")
        end
      end
    end
  end

  # Our approach to destruction is to:
  # - Set the policy to only disallow deletions based on what users of various roles should be able
  #   to destroy given various combinations of existing associations.
  # - Set association `dependent` options to avoid DB constraint errors UNLESS the destroy is never allowed.
  # - In the model spec, assume destroy has been called and test for the appropriate behavior
  #   (dependent destruction, nullification, or error) for each foreign key.
  # - In the policy spec, test for the appropriate restrictions on destroy.
  # - In the feature spec, test the destruction/deactivation/activation happy paths.
  describe "destruction" do
    let(:formula) { create(:meal_formula) }

    it "works" do
      formula.destroy
      expect(Meals::Formula.count).to be_zero
    end

    context "with associated meal" do
      let!(:meal) { create(:meal, formula: formula) }
      it { expect { formula.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end

    context "with associated role" do
      let!(:role) { create(:meal_role) }
      let!(:formula) { create(:meal_formula, roles: [role]) }

      it "destroys cleanly but leaves role" do
        formula.destroy
        expect(Meals::FormulaRole.count).to be_zero
        expect(Meals::Role.count).to eq(1)
      end
    end
  end
end
