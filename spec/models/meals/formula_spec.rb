# frozen_string_literal: true

require "rails_helper"

describe Meals::Formula do
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
