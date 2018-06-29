# frozen_string_literal: true

require "rails_helper"

describe Work::ShiftReminderJob do
  include_context "jobs"
  include_context "reminders"

  let(:time) { "2018-01-01 9:01" }
  let(:time_offset) { 0 }

  # Create periods and users in two clusters.
  let(:clusterA) { create(:cluster) }
  let(:clusterB) { create(:cluster) }
  let(:cmtyA) { create(:community, cluster: clusterA) }
  let(:cmtyB) { create(:community, cluster: clusterB) }
  let(:userA1) { create(:user, community: cmtyA) }
  let(:userA2) { create(:user, community: cmtyA) }
  let(:userB1) { create(:user, community: cmtyB) }
  let(:periodA) { create(:work_period, community: cmtyA) }
  let(:periodB) { create(:work_period, community: cmtyB) }

  # Set the time to a known value.
  around do |example|
    Timecop.freeze(Time.zone.parse(time) + time_offset) do
      example.run
    end
  end

  shared_examples_for "sends correct number of emails" do |num|
    it do
      expect(WorkMailer).to receive(:shift_reminder).exactly(num).times.and_return(mlrdbl)
      perform_job
    end
  end

  context "with multiple matching reminders in different clusters" do
    let(:jobA) { create(:work_job, period: periodA, shift_times: ["2018-01-01 11:30"], shift_slots: 3) }
    let(:jobB1) { create(:work_job, period: periodB, shift_times: ["2018-01-02 12:00"], shift_slots: 1) }
    let(:jobB2) { create(:work_job, period: periodB, shift_times: ["2018-01-03 12:00"], shift_slots: 1) }
    let!(:assignA1) { jobA.shifts.first.assignments.create!(user: userA1) }
    let!(:assignA2) { jobA.shifts.first.assignments.create!(user: userA2) }
    let!(:assignB1) { jobB1.shifts.first.assignments.create!(user: userB1) }
    let!(:assignB2) { jobB2.shifts.first.assignments.create!(user: userB1) }
    let!(:reminderA1) { create_reminder(jobA, "2018-01-01 9:00") }
    let!(:reminderB1) { create_reminder(jobB1, "2018-01-01 9:00") }
    let!(:reminderB2) { create_reminder(jobB2, "2018-01-01 9:00") }
    let!(:decoy) { create_reminder(jobB1, "2018-01-01 10:00") }

    context "slightly earlier" do
      let(:time_offset) { -2.minutes }

      it "should send nothing" do
        expect(WorkMailer).not_to receive(:shift_reminder)
        perform_job
      end
    end

    context "at appointed time" do
      it_behaves_like "sends correct number of emails", 4

      it "should send the right emails" do
        expect_delivery_to_pairs(
          [assignA1, reminderA1],
          [assignA2, reminderA1],
          [assignB1, reminderB1],
          [assignB2, reminderB2]
        )
      end
    end
  end

  context "with one reminder already sent" do
    let(:job1) { create(:work_job, period: periodB, shift_times: ["2018-01-02 12:00"], shift_slots: 1) }
    let(:job2) do
      create(:work_job, period: periodB, shift_times: ["2018-01-03 12:00", "2018-01-03 13:00"],
                        shift_count: 2, shift_slots: 1)
    end
    let!(:assign1) { job1.shifts.first.assignments.create!(user: userB1) }
    let!(:assign2) { job2.shifts.first.assignments.create!(user: userB1) }
    let!(:assign3) { job2.shifts.last.assignments.create!(user: userB1) }
    let!(:reminder1) { create_reminder(job1, "2018-01-01 9:00") }
    let!(:reminder2) { create_reminder(job2, "2018-01-01 9:00") }

    before do
      job2.shifts.first.reminder_deliveries.first.update!(delivered: true)
    end

    it_behaves_like "sends correct number of emails", 2

    it "should send the right emails" do
      expect_delivery_to_pairs(
        [assign1, reminder1],
        [assign3, reminder2]
      )
    end
  end

  def expect_delivery_to_pairs(*pairs)
    pairs.each do |pair|
      expect(WorkMailer).to receive(:shift_reminder).with(*pair).and_return(mlrdbl)
    end
    perform_job

    # Run job a second time, ensure nothing goes out.
    expect(WorkMailer).not_to receive(:shift_reminder)
    perform_job
  end
end
