# frozen_string_literal: true

require "rails_helper"

describe Meals::Assignment do
  describe "ordering" do
    let!(:role1) { create(:meal_role, title: "B") }
    let!(:role2) { create(:meal_role, title: "A") }
    let!(:meal) { create(:meal) }
    let!(:assignment1) { meal.assignments[0] }
    let!(:assignment2) { create(:meal_assignment, meal: meal, role: role1) }
    let!(:assignment3) { create(:meal_assignment, meal: meal, role: role2) }

    describe ".by_role" do
      it "orders by role title, head cook first" do
        expect(described_class.by_role.to_a).to eq([assignment1, assignment3, assignment2])
      end
    end

    describe "#<=>" do
      it do
        expect(assignment1 <=> assignment1).to eq(0) # rubocop:disable Lint/UselessComparison
        expect(assignment1 <=> assignment2).to eq(1)
        expect(assignment1 <=> assignment3).to eq(1)
        expect(assignment2 <=> assignment1).to eq(-1)
        expect(assignment2 <=> assignment2).to eq(0) # rubocop:disable Lint/UselessComparison
        expect(assignment2 <=> assignment3).to eq(1)
        expect(assignment3 <=> assignment1).to eq(-1)
        expect(assignment3 <=> assignment2).to eq(-1)
        expect(assignment3 <=> assignment3).to eq(0) # rubocop:disable Lint/UselessComparison
      end
    end
  end

  describe "timing" do
    let(:meal) { create(:meal, served_at: "2017-01-01 12:00") }
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
        expect(assignment.starts_at).to be_nil
        expect(assignment.ends_at).to be_nil
      end
    end
  end

  describe "#title" do
    let(:role) { create(:meal_role, title: "Junker") }
    let(:assignment) { create(:meal_assignment, meal: meal, role: role) }
    subject(:title) { assignment.title }

    context "with no title" do
      let(:meal) { create(:meal) }
      it { is_expected.to eq("Junker: [No Title]") }
    end

    context "with meal title" do
      let(:meal) { create(:meal, :with_menu, title: "Sushitime") }
      it { is_expected.to eq("Junker: Sushitime") }
    end
  end
end
