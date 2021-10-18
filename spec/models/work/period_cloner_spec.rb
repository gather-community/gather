# frozen_string_literal: true

require "rails_helper"

describe Work::PeriodCloner do
  let(:group) { create(:group) }
  let!(:oldp) do
    create(:work_period, name: "My Period",
                         starts_on: "2020-01-01",
                         ends_on: "2020-03-31",
                         phase: "archived",
                         auto_open_time: "2019-11-05 14:30",
                         pick_type: "staggered",
                         quota_type: "by_person",
                         round_duration: 5,
                         max_rounds_per_worker: 3,
                         workers_per_round: 10,
                         meal_job_requester: group)
  end
  subject(:cloner) { described_class.new(old_period: oldp, new_period: newp) }

  describe "#copy_attributes_and_shares" do
    let(:inactive_user) { create(:user, :inactive) }
    let!(:old_shares) do
      [
        create(:work_share, period: oldp, portion: 1),
        create(:work_share, period: oldp, portion: 0.5, priority: true),
        create(:work_share, period: oldp, portion: 1, user: inactive_user)
      ]
    end
    let(:newp) { Work::Period.new }

    it "works" do
      cloner.copy_attributes_and_shares
      expect(newp.name).to be_nil
      expect(newp.starts_on).to be_nil
      expect(newp.ends_on).to be_nil
      expect(newp.phase).to eq("draft")
      expect(newp.auto_open_time).to be_nil
      expect(newp.pick_type).to eq("staggered")
      expect(newp.quota_type).to eq("by_person")
      expect(newp.quota).to eq(0.0)
      expect(newp.round_duration).to eq(5)
      expect(newp.max_rounds_per_worker).to eq(3)
      expect(newp.workers_per_round).to eq(10)
      expect(newp.job_copy_source_id).to eq(oldp.id)
      expect(newp.meal_job_requester_id).to eq(group.id)

      expect(newp.shares.size).to eq(2)
      expect(newp.shares[0].portion).to eq(1)
      expect(newp.shares[0].priority).to be(false)
      expect(newp.shares[0].user_id).to eq(old_shares[0].user_id)
      expect(newp.shares[1].portion).to eq(0.5)
      expect(newp.shares[1].priority).to be(true)
      expect(newp.shares[1].user_id).to eq(old_shares[1].user_id)
    end
  end

  describe "#copy_jobs" do
    let!(:job1) do
      create(:work_job, title: "Job1", period: oldp, shift_count: 1,
                        time_type: "full_period", hours: 3, shift_slots: 1)
    end
    let!(:job2) do
      create(:work_job, title: "Job2", period: oldp, shift_count: 3, time_type: "date_only",
                        double_signups_allowed: true, hours: 2,
                        shift_starts: ["2020-01-01 00:00", "2020-02-01 00:00", "2020-03-01 00:00"],
                        shift_ends: ["2020-01-31 23:59", "2020-02-29 23:59", "2020-03-31 23:59"])
    end
    let!(:job3) do
      create(:work_job, title: "Job3", period: oldp, shift_count: 3, time_type: "date_only",
                        hours_per_shift: 1, hours: 3, slot_type: "full_multiple",
                        shift_starts: ["2020-02-01 00:00", "2020-02-07 00:00", "2020-02-13 00:00"],
                        shift_ends: ["2020-02-01 23:59", "2020-02-09 23:59", "2020-02-15 23:59"])
    end
    let!(:job4) do
      create(:work_job, title: "Job4", period: oldp, shift_count: 2, time_type: "date_time", hours: 1,
                        shift_starts: ["2020-02-10 12:00", "2020-03-15 17:00"],
                        shift_ends: ["2020-02-10 13:00", "2020-03-15 18:00"])
    end
    let!(:meal_job) do
      create(:work_job, title: "MealJob", period: oldp, time_type: "date_time", hours: 1,
                        meal_role: create(:meal_role))
    end
    let!(:reminder1) do
      job1.reminders.create!(abs_rel: "relative", rel_magnitude: 1, rel_unit_sign: "days_before", note: "Foo")
    end
    let!(:reminder2) do
      job1.reminders.create!(abs_rel: "absolute", abs_time: "2020-02-10 12:00", note: "Bar")
    end

    let(:attribs_copied) do
      %i[description double_signups_allowed hours hours_per_shift meal_role_id
         requester_id slot_type time_type title]
    end

    around do |example|
      # Use timezone with DST
      Time.zone = "Eastern Time (US & Canada)"
      example.run
    end

    context "without assignments" do
      context "with new period starting on month start" do
        let(:newp) { build(:work_period, starts_on: "2020-04-01", ends_on: "2020-05-15") }

        it "adjusts dates correctly, skips meal jobs, copies reminders" do
          cloner.copy_jobs
          expect(newp.jobs.size).to eq(4)

          job1n = newp.jobs.detect { |j| j.title == "Job1" }
          attribs_copied.each { |a| expect(job1n[a]).to eq(job1[a]) }
          expect(job1n.shifts.size).to eq(1)
          expect_shift_times(job1n.shifts[0], "2020-04-01 00:00", "2020-05-15 23:59")
          expect(job1n.shifts[0].slots).to eq(1)

          expect(job1n.reminders.size).to eq(2)
          reminder1n = job1n.reminders.detect { |r| r.abs_rel == "relative" }
          expect(reminder1n.class).to eq(Work::JobReminder)
          expect(reminder1n.job_id).to be_nil # Not persisted yet
          expect(reminder1n.rel_magnitude).to eq(1)
          expect(reminder1n.rel_unit_sign).to eq("days_before")
          expect(reminder1n.note).to eq("Foo")
          reminder2n = job1n.reminders.detect { |r| r.abs_rel == "absolute" }
          expect(reminder2n.abs_time).to eq(Time.zone.parse("2020-05-11 12:00"))
          expect(reminder2n.rel_magnitude).to be_nil
          expect(reminder2n.rel_unit_sign).to be_nil
          expect(reminder2n.note).to eq("Bar")

          job2n = newp.jobs.detect { |j| j.title == "Job2" }
          attribs_copied.each { |a| expect(job2n[a]).to eq(job2[a]) }
          expect(job2n.shifts.size).to eq(2)
          # This shift stays at month boundaries.
          expect_shift_times(job2n.shifts[0], "2020-04-01 00:00", "2020-04-30 23:59")
          # This shift stays at month start but gets clipped at end of period.
          expect_shift_times(job2n.shifts[1], "2020-05-01 00:00", "2020-05-15 23:59")
          # The third shift is dropped entirely.

          job3n = newp.jobs.detect { |j| j.title == "Job3" }
          attribs_copied.each { |a| expect(job3n[a]).to eq(job3[a]) }
          expect(job3n.shifts.size).to eq(3)
          # This moves a day later even though it was at month start b/c it didn't end at month end.
          expect_shift_times(job3n.shifts[0], "2020-05-02 00:00", "2020-05-02 23:59")
          # This moves a day later b/c Jan has 31 days but Apr has 30
          expect_shift_times(job3n.shifts[1], "2020-05-08 00:00", "2020-05-10 23:59")
          # This gets clipped at the end of the period, now one day instead of 2.
          expect_shift_times(job3n.shifts[2], "2020-05-14 00:00", "2020-05-15 23:59")

          job4n = newp.jobs.detect { |j| j.title == "Job4" }
          attribs_copied.each { |a| expect(job4n[a]).to eq(job4[a]) }
          expect(job4n.shifts.size).to eq(1)
          # This moves a day later b/c Jan has 31 days but Apr has 30
          expect_shift_times(job4n.shifts[0], "2020-05-11 12:00", "2020-05-11 13:00")
          # The second shift is dropped entirely.

          [job1n, job2n, job3n, job4n].each do |job|
            job.shifts.each { |s| expect(s.assignments).to be_empty }
          end

          expect(newp).to be_valid
        end
      end

      context "with new period not starting on month start" do
        let(:newp) { build(:work_period, starts_on: "2020-04-05", ends_on: "2020-05-20") }

        it "adjusts dates correctly" do
          cloner.copy_jobs

          job2n = newp.jobs.detect { |j| j.title == "Job2" }
          attribs_copied.each { |a| expect(job2n[a]).to eq(job2[a]) }
          expect(job2n.shifts.size).to eq(2)
          # These shift don't stay at month boundaries now.
          expect_shift_times(job2n.shifts[0], "2020-04-05 00:00", "2020-05-05 23:59")
          expect_shift_times(job2n.shifts[1], "2020-05-06 00:00", "2020-05-20 23:59")

          expect(newp).to be_valid
        end
      end

      context "with short period such that at least one job would have no shifts" do
        let(:newp) { build(:work_period, starts_on: "2020-04-01", ends_on: "2020-04-30") }

        it "adjusts dates correctly" do
          cloner.copy_jobs

          job3n = newp.jobs.detect { |j| j.title == "Job3" }
          attribs_copied.each { |a| expect(job3n[a]).to eq(job3[a]) }
          expect(job3n.shifts.size).to eq(1)
          # The first shift of this job is moved back so that it fits in the period.
          expect_shift_times(job3n.shifts[0], "2020-04-30 00:00", "2020-04-30 23:59")

          expect(newp).to be_valid
        end
      end

      context "with new period with both month boundaries" do
        let(:newp) { build(:work_period, starts_on: "2020-05-01", ends_on: "2020-06-30") }

        it "adjusts dates correctly, skips meal jobs" do
          cloner.copy_jobs

          job2n = newp.jobs.detect { |j| j.title == "Job2" }
          attribs_copied.each { |a| expect(job2n[a]).to eq(job2[a]) }
          expect(job2n.shifts.size).to eq(2)
          # These shifts stay at month boundaries.
          expect_shift_times(job2n.shifts[0], "2020-05-01 00:00", "2020-05-31 23:59")
          expect_shift_times(job2n.shifts[1], "2020-06-01 00:00", "2020-06-30 23:59")
          # The third shift is dropped entirely.

          job3n = newp.jobs.detect { |j| j.title == "Job3" }
          attribs_copied.each { |a| expect(job3n[a]).to eq(job3[a]) }
          expect(job3n.shifts.size).to eq(3)
          expect_shift_times(job3n.shifts[0], "2020-06-01 00:00", "2020-06-01 23:59")
          expect_shift_times(job3n.shifts[1], "2020-06-07 00:00", "2020-06-09 23:59")
          expect_shift_times(job3n.shifts[2], "2020-06-13 00:00", "2020-06-15 23:59")

          job4n = newp.jobs.detect { |j| j.title == "Job4" }
          attribs_copied.each { |a| expect(job4n[a]).to eq(job4[a]) }
          expect(job4n.shifts.size).to eq(1)
          expect_shift_times(job4n.shifts[0], "2020-06-10 12:00", "2020-06-10 13:00")
          # The second shift is dropped entirely.

          expect(newp).to be_valid
        end
      end
    end

    context "with assignments" do
      before do
        oldp.update!(phase: "draft", auto_open_time: Time.current.tomorrow)
        # These will be preassigned
        job2.shifts[0].assignments.create!(user: create(:user))
        job2.shifts[0].assignments.create!(user: create(:user, :inactive))

        oldp.update!(phase: "open")
        # These won't be preassigned
        job2.shifts[0].assignments.create!(user: create(:user))
      end

      context "without copy_preassignments" do
        let(:newp) { build(:work_period, starts_on: "2020-04-01", ends_on: "2020-04-30") }

        it "copies no assignments" do
          cloner.copy_jobs
          expect(newp.jobs.flat_map(&:shifts).flat_map(&:assignments).size).to be_zero
        end
      end

      context "with copy_preassignments" do
        let(:newp) do
          build(:work_period, starts_on: "2020-04-01", ends_on: "2020-04-30", copy_preassignments: true)
        end

        it "copies pre-assignments" do
          cloner.copy_jobs

          expect(newp.jobs.flat_map(&:shifts).flat_map(&:assignments).size).to eq(1)
          new_assignment = newp.jobs.detect { |j| j.title == "Job2" }.shifts[0].assignments[0]
          expect(new_assignment.preassigned).to be(true)
          expect(new_assignment.shift.starts_at).to eq(Time.zone.parse("2020-04-01 00:00"))
          expect(new_assignment.job.title).to eq("Job2")

          expect(newp).to be_valid
        end
      end
    end

    def expect_shift_times(shift, start_time, end_time)
      expect(shift.starts_at).to eq(Time.zone.parse(start_time))
      expect(shift.ends_at).to eq(Time.zone.parse(end_time))
    end
  end
end
