# frozen_string_literal: true

require "rails_helper"

describe Meals::ShiftReminderJob do
  include_context "jobs"
  let(:time) { "2018-01-01 9:01" }
  let(:time_offset) { 0 }

  # Create objects in two clusters.
  let(:clusterA) { create(:cluster) }
  let(:clusterB) { create(:cluster) }
  let(:cmtyA) { create(:community, cluster: clusterA) }
  let(:cmtyB) { create(:community, cluster: clusterB) }
  let(:userA1) { create(:user, community: cmtyA) }
  let(:userB1) { create(:user, community: cmtyB) }
  let(:userB2) { create(:user, community: cmtyB) }
  let(:roleAhc) { create(:meal_role, :head_cook, community: cmtyA) }
  let(:roleBhc) { create(:meal_role, :head_cook, community: cmtyB) }
  let(:roleBac) { create(:meal_role, community: cmtyB, title: "Assistant Cook") }
  let(:formulaA) { create(:meal_formula, community: cmtyA, roles: [roleAhc]) }
  let(:formulaB) { create(:meal_formula, community: cmtyB, roles: [roleBhc, roleBac]) }
  let(:mealA) do
    create(:meal, community: cmtyA, formula: formulaA, head_cook: userA1, served_at: "2018-01-03 18:00")
  end
  let(:mealB1) do
    create(:meal, community: cmtyB, formula: formulaB, head_cook: userB1, served_at: "2018-01-02 18:00")
  end
  let(:mealB2) do
    create(:meal, community: cmtyB, formula: formulaB, head_cook: userB2, served_at: "2018-01-02 18:00")
  end
  let!(:assignAhc) { mealA.assignments[0] }
  let!(:assignB1hc) { mealB1.assignments[0] }
  let!(:assignB1ac) { create(:meal_assignment, meal: mealB1, role: roleBac) }
  let!(:assignB2hc) { mealB2.assignments[0] }
  let!(:assignB2ac) { create(:meal_assignment, meal: mealB2, role: roleBac) }
  let!(:reminderAhc) { create_reminder(role: roleAhc, rel_magnitude: 2, rel_unit_sign: "days_before") }
  let!(:reminderBhc) { create_reminder(role: roleBhc, rel_magnitude: 1, rel_unit_sign: "days_before") }
  let!(:reminderBac) { create_reminder(role: roleBac, rel_magnitude: 1, rel_unit_sign: "days_before") }

  # Set the time to a known value.
  around do |example|
    Timecop.freeze(Time.zone.parse(time) + time_offset) do
      example.run
    end
  end

  shared_examples_for "sends correct number of emails" do |num|
    it do
      expect(MealMailer).to receive(:shift_reminder).exactly(num).times.and_return(mlrdbl)
      perform_job
    end
  end

  context "with multiple matching reminders in different clusters" do
    # Add a decoy to ensure we don't blindly send all reminders for a role if one of them matches.
    let!(:decoy) { create_reminder(role: roleBac, rel_magnitude: 4, rel_unit_sign: "hours_after") }

    context "slightly earlier" do
      let(:time_offset) { -2.minutes }

      it "should send nothing" do
        expect(MealMailer).not_to receive(:shift_reminder)
        perform_job
      end
    end

    context "at appointed time" do
      it_behaves_like "sends correct number of emails", 5

      it "should send the right emails" do
        expect_delivery_to_pairs(
          [assignAhc, reminderAhc],
          [assignB1hc, reminderBhc],
          [assignB1ac, reminderBac],
          [assignB2hc, reminderBhc],
          [assignB2ac, reminderBac]
        )
      end
    end
  end

  context "with one reminder already sent and one too far in past" do
    # Make this one too long ago so it won't be sent even though it's past deadline and not delivered.
    let!(:reminderBac) { create_reminder(role: roleBac, rel_magnitude: 2, rel_unit_sign: "days_before") }

    before do
      assignB1hc.reminder_deliveries[0].update!(delivered: true)
    end

    context "at appointed time" do
      it_behaves_like "sends correct number of emails", 2

      it "should send the right emails" do
        expect_delivery_to_pairs(
          [assignAhc, reminderAhc],
          [assignB2hc, reminderBhc]
        )
      end
    end
  end

  def create_reminder(role:, rel_magnitude:, rel_unit_sign:)
    create(:meal_role_reminder, role: role, rel_magnitude: rel_magnitude, rel_unit_sign: rel_unit_sign)
  end

  def expect_delivery_to_pairs(*pairs)
    pairs.each do |pair|
      expect(MealMailer).to receive(:shift_reminder).with(*pair).and_return(mlrdbl)
    end
    perform_job

    # Run job a second time, ensure nothing goes out.
    expect(MealMailer).not_to receive(:shift_reminder)
    perform_job
  end
end
