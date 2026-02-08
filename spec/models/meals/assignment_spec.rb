# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_assignments
#
#  id                       :integer          not null, primary key
#  cluster_id               :integer          not null
#  cook_menu_reminder_count :integer          default(0), not null
#  created_at               :datetime         not null
#  meal_id                  :integer          not null
#  role_id                  :bigint           not null
#  updated_at               :datetime         not null
#  user_id                  :integer          not null
#
require "rails_helper"

describe Meals::Assignment do
  describe "ordering" do
    let!(:role1) { create(:meal_role, :head_cook) }
    let!(:role2) { create(:meal_role, title: "B") }
    let!(:role3) { create(:meal_role, title: "A") }
    let(:formula) { create(:meal_formula, roles: [role1, role2, role3]) }
    let!(:meal) { create(:meal, formula: formula, head_cook: false) }
    let!(:assignment1) { create(:meal_assignment, meal: meal, role: role1) }
    let!(:assignment2) { create(:meal_assignment, meal: meal, role: role2) }
    let!(:assignment3) { create(:meal_assignment, meal: meal, role: role3) }

    describe ".by_role" do
      it "orders by role title, head cook first" do
        expect(described_class.by_role.to_a).to eq([assignment1, assignment3, assignment2])
      end
    end

    describe "#<=>" do
      it do
        expect(assignment1 <=> assignment1).to eq(0)
        expect(assignment1 <=> assignment2).to eq(1)
        expect(assignment1 <=> assignment3).to eq(1)
        expect(assignment2 <=> assignment1).to eq(-1)
        expect(assignment2 <=> assignment2).to eq(0)
        expect(assignment2 <=> assignment3).to eq(1)
        expect(assignment3 <=> assignment1).to eq(-1)
        expect(assignment3 <=> assignment2).to eq(-1)
        expect(assignment3 <=> assignment3).to eq(0)
      end
    end
  end

  describe "timing" do
    let(:formula) { create(:meal_formula, roles: [create(:meal_role, :head_cook), role]) }
    let(:meal) { create(:meal, formula: formula, served_at: "2017-01-01 12:00") }
    let(:assignment) { create(:meal_assignment, meal: meal, role: role) }

    context "for date_time role" do
      let(:role) { create(:meal_role, time_type: "date_time", shift_start: -120, shift_end: 30) }

      it do
        expect(assignment.starts_at).to eq(Time.zone.parse("2017-01-01 10:00"))
        expect(assignment.ends_at).to eq(Time.zone.parse("2017-01-01 12:30"))
      end
    end

    context "for date_only role" do
      let(:role) { create(:meal_role, time_type: "date_only") }

      it do
        expect(assignment.starts_at).to eq(Date.parse("2017-01-01"))
        expect(assignment.ends_at).to eq(Date.parse("2017-01-01"))
      end
    end
  end

  describe "validation" do
    describe "role" do
      let(:formula) { create(:meal_formula, :with_two_roles) }

      context "on create" do
        let(:meal) { build(:meal, formula: formula, head_cook: false) }
        subject(:assignment) { build(:meal_assignment, meal: meal, role: role, user: create(:user)) }

        context "with valid role" do
          let(:role) { formula.head_cook_role }
          it { is_expected.to be_valid }
        end

        context "with invalid role" do
          let(:role) { create(:meal_role, title: "Foo") }
          it { is_expected.to have_errors(user_id: /Role 'Foo' does not match the selected formula/) }
        end
      end

      context "on update" do
        let!(:meal) { create(:meal, formula: formula, head_cook: create(:user), asst_cooks: [create(:user)]) }
        subject(:assignment) { meal.assignments[1] }

        before do
          formula.roles.delete(formula.roles.detect { |r| r.title == "Assistant Cook" })
        end

        context "with now-invalid role" do
          it "does not error on update!" do
            assignment.update!(user: create(:user))
          end
        end
      end
    end
  end
end
