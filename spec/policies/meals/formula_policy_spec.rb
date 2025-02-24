# frozen_string_literal: true

require "rails_helper"

describe Meals::FormulaPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:formula) { create(:meal_formula) }
    let(:record) { formula }

    permissions :index?, :show? do
      it_behaves_like "permits cluster and super admins"
      it_behaves_like "permits users in cluster"
    end

    permissions :new?, :create?, :edit?, :update?, :destroy?, :deactivate? do
      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator
    end

    permissions :activate? do
      before { record.deactivate }
      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator
    end

    context "with existing meals" do
      before { allow(formula).to receive(:meals?).and_return(true) }

      permissions :deactivate?, :edit?, :update? do
        it "permits" do
          expect(subject).to permit(admin, formula)
        end
      end

      permissions :activate? do
        before { record.deactivate }

        it "permits if formula is inactive" do
          expect(subject).to permit(admin, formula)
        end
      end

      permissions :update_calcs?, :destroy? do
        it "forbids" do
          expect(subject).not_to permit(admin, formula)
        end
      end
    end

    context "if default formula" do
      before { formula.is_default = true }

      permissions :edit?, :update? do
        it "permits" do
          expect(subject).to permit(admin, formula)
        end
      end

      permissions :activate? do
        before { record.deactivate }

        it "permits if formula is inactive" do
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
    include_context "policy scopes"
    let(:klass) { Meals::Formula }
    let!(:formulas) { create_list(:meal_formula, 3) }

    before do
      formulas.last.deactivate
    end

    shared_examples_for "returns all formulas" do
      it { is_expected.to match_array(formulas) }
    end

    shared_examples_for "returns active formulas only" do
      it { is_expected.to match_array(formulas[0..1]) }
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
      let(:actor) { userB }
      it_behaves_like "returns active formulas only"
    end
  end

  describe "permitted attributes" do
    let(:formula) { create(:meal_formula) }
    let(:admin) { create(:admin) }
    let(:base_attribs) { %i[name is_default pantry_reimbursement takeout] << {role_ids: []} }
    subject { Meals::FormulaPolicy.new(admin, formula).permitted_attributes }

    context "with no meals" do
      it "should allow all attribs" do
        expect(subject).to contain_exactly(:meal_calc_type, :pantry_calc_type,
                                           :pantry_fee_formatted, *base_attribs,
                                           parts_attributes: [:id, :type_id, :share_formatted, :portion_size,
                                                              :_destroy, {type_attributes: %i[name]}])
      end
    end

    context "with existing meals" do
      before { allow(formula).to receive(:meals?).and_return(true) }

      it "should not allow restricted attribs" do
        expect(subject).to contain_exactly(*base_attribs)
      end
    end
  end
end
