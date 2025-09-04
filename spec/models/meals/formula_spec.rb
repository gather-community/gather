# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_formulas
#
#  id                   :integer          not null, primary key
#  cluster_id           :integer          not null
#  community_id         :integer          not null
#  created_at           :datetime         not null
#  deactivated_at       :datetime
#  is_default           :boolean          default(FALSE), not null
#  meal_calc_type       :string           not null
#  name                 :string           not null
#  pantry_calc_type     :string           not null
#  pantry_fee           :decimal(10, 4)   not null
#  pantry_reimbursement :boolean          default(FALSE)
#  takeout              :boolean          default(TRUE), not null
#  updated_at           :datetime         not null
#
require "rails_helper"

describe Meals::Formula do
  describe "validation" do
    describe "at_least_one_type" do
      subject(:formula) { build(:meal_formula, parts_attrs: parts_attrs, meal_calc_type: calc_type) }

      context "fixed type" do
        let(:calc_type) { "fixed" }

        context "with no parts" do
          let(:parts_attrs) { [] }
          it { is_expected.to have_errors(parts: "must include at least one meal type") }
        end

        context "with all zero parts" do
          let(:parts_attrs) { %w[0 0] }
          it { is_expected.to be_valid }
        end

        context "with parts" do
          let(:parts_attrs) { %w[2 3] }
          it { is_expected.to be_valid }
        end
      end

      context "share type" do
        let(:calc_type) { "share" }

        context "with all zero parts" do
          let(:parts_attrs) { %w[0 0] }
          it { is_expected.to have_errors(parts: "must include at least one non-zero meal type") }
        end

        context "with parts" do
          let(:parts_attrs) { %w[100% 50%] }
          it { is_expected.to be_valid }
        end
      end
    end

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

    describe "share numericality" do
      subject(:formula) { build(:meal_formula, parts_attrs: parts_attrs, meal_calc_type: calc_type) }

      context "percentage" do
        let(:parts_attrs) { %w[10% 20%] }
        let(:calc_type) { "share" }

        it do
          is_expected.to be_valid
          expect(formula.parts[0].share).to be_within(0.005).of(0.1)
          expect(formula.parts[1].share).to be_within(0.005).of(0.2)
        end
      end

      context "currency" do
        let(:parts_attrs) { %w[4 .50] }
        let(:calc_type) { "fixed" }

        it do
          is_expected.to be_valid
          expect(formula.parts[0].share).to be_within(0.005).of(4)
          expect(formula.parts[1].share).to be_within(0.005).of(0.5)
        end
      end

      context "negative" do
        let(:parts_attrs) { %w[-1 0.50] }
        let(:calc_type) { "fixed" }

        it "should strip -" do
          is_expected.to be_valid
          expect(formula.parts[0].share).to be_within(0.005).of(1)
          expect(formula.parts[1].share).to be_within(0.005).of(0.5)
        end
      end

      context "non-numeric" do
        let(:parts_attrs) { %w[x 0.50] }
        let(:calc_type) { "fixed" }
        it { is_expected.to have_errors("parts.share_formatted": "is invalid") }
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

    context "with no associated objects" do
      it "works" do
        formula.destroy
        expect(Meals::Formula.count).to be_zero
      end
    end

    context "with associated meal" do
      let!(:meal) { create(:meal, formula: formula) }
      it { expect { formula.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end

    context "with associated meal job sync setting" do
      let(:period) { create(:work_period) }

      before do
        formula.work_meal_job_sync_settings.create!(period: period, formula: formula,
                                                    role: formula.roles.first)
      end

      it "destroys setting record" do
        formula.destroy
        expect(Meals::Formula.count).to be_zero
        expect(Work::MealJobSyncSetting.count).to be_zero
      end
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
