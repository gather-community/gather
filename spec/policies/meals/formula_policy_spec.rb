require 'rails_helper'

describe Meals::FormulaPolicy do
  include_context "policy objs"

  describe "permissions" do
    let(:formula) { build(:meal_formula, community: community) }
    let(:record) { formula }

    permissions :index?, :show? do
      it_behaves_like "permits users in cluster"
    end

    permissions :new?, :create?, :edit?, :update?, :destroy?, :activate?, :deactivate? do
      it_behaves_like "permits admins or special role but not regular users", "meals_coordinator"
    end

    context "with existing meals" do
      before { allow(formula).to receive(:has_meals?).and_return(true) }

      permissions :activate?, :deactivate? do
        it "permits" do
          expect(subject).to permit(admin, formula)
        end
      end

      permissions :edit?, :update?, :destroy? do
        it "forbids" do
          expect(subject).not_to permit(admin, formula)
        end
      end
    end

    context "if default formula" do
      before { formula.is_default = true }

      permissions :edit?, :update?, :activate? do
        it "permits" do
          expect(subject).to permit(admin, formula)
        end
      end

      permissions :destroy?, :deactivate? do
        it "forbids" do
          expect(subject).not_to permit(admin, formula)
        end
      end
    end
  end

  describe "scope" do
    let!(:formulas) { create_list(:meal_formula, 3, community: community) }
    let(:permitted) { Meals::FormulaPolicy::Scope.new(actor, Meals::Formula.all).resolve }

    before do
      save_policy_objects!(community)
      formulas.last.deactivate!
    end

    shared_examples_for "returns all formulas" do
      it { expect(permitted).to match_array(formulas) }
    end

    shared_examples_for "returns active formulas only" do
      it { expect(permitted).to match_array(formulas[0..1]) }
    end

    context "admin" do
      let(:actor) { admin }
      it_behaves_like "returns all formulas"
    end

    context "meals_coordinator" do
      let(:actor) { meals_coordinator }
      it_behaves_like "returns all formulas"
    end

    context "regular user" do
      let(:actor) { user }
      it_behaves_like "returns active formulas only"
    end

    context "regular user in cluster" do
      let(:actor) { user_in_cmtyB }
      it_behaves_like "returns active formulas only"
    end
  end

  describe "permitted attributes" do
    subject { Meals::FormulaPolicy.new(User.new, Meals::Formula.new).permitted_attributes }

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(:name, :is_default, :meal_calc_type, :pantry_calc_type,
        :pantry_fee_disp, *Signup::SIGNUP_TYPES.map { |st| "#{st}_disp".to_sym })
    end
  end
end
