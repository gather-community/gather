# frozen_string_literal: true

require "rails_helper"

describe Work::ShiftReminderJob do
  include_context "jobs"

  # Create periods and users in two clusters.
  let(:clusterA) { create(:cluster) }
  let(:clusterB) { create(:cluster) }
  let(:cmtyA) { create(:community, cluster: clusterA) }
  let(:cmtyB) { create(:community, cluster: clusterB) }
  let(:userA1) { create(:user, community: cmtyA) }
  let(:userA2) { create(:user, community: cmtyA) }
  let(:userB1) { create(:user, community: cmtyB) }
  let(:period1) { create(:work_period, community: cmtyA) }
  let(:period2) { create(:work_period, community: cmtyB) }

  # Both jobs have one shift only.
  let(:jobA) { create(:work_job, period: period1, shift_times: ["2018-01-01 11:00"], shift_slots: 3) }
  let(:jobB1) { create(:work_job, period: period2, shift_times: ["2018-01-01 12:00"], shift_slots: 1) }
  let(:jobB2) { create(:work_job, period: period2, shift_times: ["2018-01-01 13:00"], shift_slots: 1) }

  # Assign users to all slots for both jobs.
  let!(:assignA1) { jobA.shifts.first.assignments.create!(user: userA1) }
  let!(:assignA2) { jobA.shifts.first.assignments.create!(user: userA2) }
  let!(:assignB1) { jobB1.shifts.first.assignments.create!(user: userB1) }
  let!(:assignB2) { jobB2.shifts.first.assignments.create!(user: userB1) }

  # rel_time is in minutes, relative to shift_times above
  let!(:reminderA1) { create(:work_reminder, job: jobA, rel_time: -120, abs_time: nil) }
  let!(:reminderA2) { create(:work_reminder, job: jobA, abs_time: "2018-01-01 9:00", rel_time: nil) }
  let!(:reminderB1) { create(:work_reminder, job: jobB1, rel_time: -180, abs_time: nil) }
  let!(:reminderB2) { create(:work_reminder, job: jobB1, rel_time: 60, abs_time: nil) }
  let!(:reminderB3) { create(:work_reminder, job: jobB2, rel_time: -240, abs_time: nil) }

  # Set the time to a known value.
  around do |example|
    Timecop.freeze(time) do
      example.run
    end
  end

  before do
    # Mark reminderA1 as already sent for jobA's only shift.
    # So only reminderA2 will get delivered for jobA.
    Work::ReminderDelivery.create!(reminder: reminderA1, shift: jobA.shifts.first)
  end

  context "with three matching reminders in different clusters, one already sent" do
    let(:time) { "2018-01-01 9:01" }

    it "should send the right number of emails" do
      expect(WorkMailer).to receive(:shift_reminder).exactly(4).times.and_return(mlrdbl)
      perform_job
    end

    it "should send the right emails" do
      expect(WorkMailer).to receive(:shift_reminder).with(assignA1, reminderA2).and_return(mlrdbl)
      expect(WorkMailer).to receive(:shift_reminder).with(assignA2, reminderA2).and_return(mlrdbl)
      expect(WorkMailer).to receive(:shift_reminder).with(assignB1, reminderB1).and_return(mlrdbl)
      expect(WorkMailer).to receive(:shift_reminder).with(assignB2, reminderB3).and_return(mlrdbl)
      perform_job
      expect(WorkMailer).not_to receive(:shift_reminder)
      perform_job
    end
  end

  context "with no matching reminders" do
    let(:time) { "2018-01-01 8:00" }

    it "should send no emails" do
      expect(WorkMailer).not_to receive(:shift_reminder)
      perform_job
    end
  end
end
