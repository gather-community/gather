# frozen_string_literal: true

require "rails_helper"

describe CustomReminderJob do
  include_context "jobs"
  include_context "reminders"

  let(:time) { "2018-01-01 6:01" }
  let(:time_offset) { 0 }

  # Create periods and users in two clusters.
  let(:clusterA) { create(:cluster) }
  let(:clusterB) { create(:cluster) }
  let(:cmtyA) { create(:community, cluster: clusterA) }
  let(:cmtyB) { create(:community, cluster: clusterB) }
  let(:userA1) { create(:user, community: cmtyA) }
  let(:userA2) { create(:user, community: cmtyA) }
  let(:userB1) { create(:user, community: cmtyB) }
  let(:userB2) { create(:user, community: cmtyB) }

  # Set the time to a known value.
  around do |example|
    Timecop.freeze(Time.zone.parse(time) + time_offset) do
      example.run
    end
  end

  shared_examples_for "sends correct number of emails" do |num|
    it do
      expect(WorkMailer).to receive(:job_reminder).exactly(num).times.and_return(mlrdbl)
      perform_job
    end
  end

  # This block covers the general behavior for CustomReminderJob.
  # A later block covers correct hookup of other reminder types.
  describe "work job reminders" do
    let(:periodA) { create(:work_period, community: cmtyA) }
    let(:periodB) { create(:work_period, community: cmtyB) }

    context "with multiple matching reminders in different clusters" do
      let(:work_jobA) do
        create(:work_job, period: periodA, shift_starts: ["2018-01-01 11:30"], shift_slots: 3)
      end
      let(:work_jobB1) do
        create(:work_job, period: periodB, shift_starts: ["2018-01-02 12:00"], shift_slots: 1)
      end
      let(:work_jobB2) do
        create(:work_job, period: periodB, shift_starts: ["2018-01-03 12:00"], shift_slots: 1)
      end
      let!(:assignA1) { work_jobA.shifts[0].assignments.create!(user: userA1) }
      let!(:assignA2) { work_jobA.shifts[0].assignments.create!(user: userA2) }
      let!(:assignB1) { work_jobB1.shifts[0].assignments.create!(user: userB1) }
      let!(:assignB2) { work_jobB2.shifts[0].assignments.create!(user: userB1) }
      let!(:reminderA1) { create_work_job_reminder(work_jobA, "2018-01-01 6:00") }
      let!(:reminderB1) { create_work_job_reminder(work_jobB1, "2018-01-01 6:00") }
      let!(:reminderB2) { create_work_job_reminder(work_jobB2, "2018-01-01 6:00") }
      let!(:decoy) { create_work_job_reminder(work_jobB1, "2018-01-01 10:00") }
      let!(:other_reminder) { create_work_job_reminder(work_jobB1, "2018-01-01 8:00") }
      let!(:old_stray_delivery) do
        other_reminder.deliveries[0].tap { |d| d.update!(deliver_at: 1.day.ago) }
      end

      context "slightly earlier" do
        let(:time_offset) { -2.minutes }

        it "should send nothing but delete old delivery" do
          expect(WorkMailer).not_to receive(:job_reminder)
          perform_job
          expect { old_stray_delivery.reload }.to raise_error(ActiveRecord::RecordNotFound)
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

    context "with one reminder already sent and one too far in past" do
      let(:work_job1) do
        create(:work_job, period: periodB, shift_starts: ["2018-01-02 12:00"], shift_slots: 1)
      end
      let(:work_job2) do
        create(:work_job, period: periodB, shift_starts: ["2018-01-03 12:00", "2018-01-03 13:00"],
                          shift_count: 2, shift_slots: 1)
      end
      let!(:assign1) { work_job1.shifts[0].assignments.create!(user: userB1) }
      let!(:assign2) { work_job2.shifts[0].assignments.create!(user: userB1) }
      let!(:assign3) { work_job2.shifts[-1].assignments.create!(user: userB1) }
      let!(:reminder1) { create_work_job_reminder(work_job1, "2018-01-01 6:00") }
      let!(:reminder2) { create_work_job_reminder(work_job2, "2018-01-01 6:00") }
      let!(:reminder3) { create_work_job_reminder(work_job1, "2018-01-01 5:30") }
      let!(:reminder4) { create_work_job_reminder(work_job1, "2018-01-01 3:00") } # Too early

      before do
        work_job2.shifts[0].reminder_deliveries.index_by(&:reminder)[reminder2].destroy
      end

      it_behaves_like "sends correct number of emails", 3

      it "should send the right emails" do
        expect_delivery_to_pairs(
          [assign1, reminder3],
          [assign1, reminder1],
          [assign3, reminder2]
        )
      end
    end
  end

  describe "multiple reminder types" do
    let(:period) { create(:work_period, community: cmtyB) }
    let(:work_job) { create(:work_job, period: period, shift_starts: ["2018-01-02 12:00"], shift_slots: 1) }
    let!(:shift_assignment) { work_job.shifts[0].assignments.create!(user: userB1) }
    let!(:job_reminder) { create_work_job_reminder(work_job, "2018-01-01 6:00") }

    let(:role) { create(:meal_role, :head_cook, community: cmtyA) }
    let(:formula) { create(:meal_formula, community: cmtyA, roles: [role]) }
    let(:meal) do
      create(:meal, community: cmtyA, formula: formula, head_cook: userA1, served_at: "2018-01-03 18:00")
    end
    let!(:meal_assignment) { meal.assignments[0] }
    let!(:role_reminder) { create_meal_role_reminder(role, 2, "days_before") }

    it "calls appropriate mailers" do
      expect(WorkMailer).to receive(:job_reminder).with(shift_assignment, job_reminder).and_return(mlrdbl)
      expect(MealMailer).to receive(:role_reminder).with(meal_assignment, role_reminder).and_return(mlrdbl)
      perform_job
    end
  end

  def expect_delivery_to_pairs(*pairs)
    pairs.each do |pair|
      expect(WorkMailer).to receive(:job_reminder).with(*pair).and_return(mlrdbl)
    end
    perform_job

    # Run job a second time, ensure nothing goes out.
    expect(WorkMailer).not_to receive(:job_reminder)
    perform_job
  end
end
