# frozen_string_literal: true

require "rails_helper"

describe Meals::Role do
  describe "normalization" do
    let(:role) { build(:meal_role, submitted) }

    # Get the normalized values for the submitted keys.
    subject { submitted.keys.index_with { |k| role.send(k) }.to_h }

    before do
      role.validate
    end

    describe "offsets and work hours" do
      context "date_only with offsets" do
        let(:submitted) { {time_type: "date_only", shift_start: -90, shift_end: 0, work_hours: 3} }
        it { is_expected.to eq(time_type: "date_only", shift_start: nil, shift_end: nil, work_hours: 3) }
      end

      context "date_only with offsets, no work hours" do
        let(:submitted) { {time_type: "date_only", shift_start: -90, shift_end: 0, work_hours: nil} }
        it { is_expected.to eq(time_type: "date_only", shift_start: nil, shift_end: nil, work_hours: nil) }
      end

      context "date_time with offsets" do
        let(:submitted) { {time_type: "date_time", shift_start: -90, shift_end: 0, work_hours: 3} }
        it { is_expected.to eq(time_type: "date_time", shift_start: -90, shift_end: 0, work_hours: 1.5) }
      end

      context "date_time with no offsets" do
        let(:submitted) { {time_type: "date_time", shift_start: nil, shift_end: nil, work_hours: 3} }
        it { is_expected.to eq(time_type: "date_time", shift_start: nil, shift_end: nil, work_hours: nil) }
      end
    end

    describe "count_per_meal" do
      context "head_cook" do
        let(:submitted) { {special: "head_cook", count_per_meal: 3} }
        it { is_expected.to eq(special: "head_cook", count_per_meal: 1) }
      end

      context "not head_cook" do
        let(:submitted) { {special: nil, count_per_meal: 3} }
        it { is_expected.to eq(special: nil, count_per_meal: 3) }
      end
    end
  end

  describe "validation" do
    describe "shift_time_positive" do
      subject(:role) do
        build(:meal_role, time_type: "date_time", shift_start: shift_start, shift_end: shift_end)
      end

      context "with positive elapsed time" do
        let(:shift_start) { -90 }
        let(:shift_end) { -30 }
        it { is_expected.to be_valid }
      end

      context "with zero elapsed time" do
        let(:shift_start) { 30 }
        let(:shift_end) { 30 }
        it { is_expected.to have_errors(shift_end: /Must be after/) }
      end

      context "with negative elapsed time" do
        let(:shift_start) { 30 }
        let(:shift_end) { -30 }
        it { is_expected.to have_errors(shift_end: /Must be after/) }
      end
    end

    describe "offsets required" do
      subject(:role) do
        build(:meal_role, time_type: time_type)
      end

      context "when date_time" do
        let(:time_type) { "date_time" }
        it { is_expected.to have_errors(shift_start: /can't be blank/, shift_end: /can't be blank/) }
      end

      context "when not date_time" do
        let(:time_type) { "date_only" }
        it { is_expected.to be_valid }
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
    let(:role) { create(:meal_role) }

    context "with reminder" do
      let(:role) { create(:meal_role, :with_reminder) }

      it "destroys reminder" do
        role.destroy
        expect(Meals::Role.count).to be_zero
        expect(Meals::RoleReminder.count).to be_zero
      end
    end

    context "with associated meal job sync setting" do
      let(:period) { create(:work_period) }
      let(:formula) { create(:meal_formula, roles: [role]) }

      before do
        role.work_meal_job_sync_settings.create!(period: period, formula: formula, role: role)
      end

      it "destroys setting record" do
        expect { role.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end

    context "with associated formula" do
      let!(:formula) { create(:meal_formula, roles: [role]) }
      it { expect { role.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end

    context "with associated job" do
      let!(:job) { create(:work_job, meal_role_id: role.id) }
      it { expect { role.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end

    context "with associated meal assignment" do
      let(:formula) { create(:meal_formula, roles: [create(:meal_role, :head_cook), role]) }
      let(:meal) { create(:meal, formula: formula) }
      let!(:meal_assignment) { create(:meal_assignment, meal: meal, role: role) }
      it { expect { role.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end
  end
end
