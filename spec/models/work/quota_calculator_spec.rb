# frozen_string_literal: true

require "rails_helper"

describe Work::QuotaCalculator do
  let(:quota_type) { "by_person" }
  let!(:period) { create(:work_period, quota_type: quota_type) }
  let!(:users) { create_list(:user, 6) }
  subject { described_class.new(period).calculate }

  context "with no jobs or shares" do
    it { is_expected.to be_zero }
  end

  context "with shares but no jobs" do
    before do
      [1, 0, 1, 1, 0.5, 0.5].each_with_index { |p, i| period.shares.create!(user: users[i], portion: p) }
    end
    it { is_expected.to be_zero }
  end

  context "with jobs" do
    let!(:job1) do # 30 hours total
      create(:work_job, period: period, hours: 3, shift_count: 2, shift_slots: 5)
    end
    let!(:job2) do # 1.5 hours total
      create(:work_job, period: period, time_type: "full_period", hours: 0.5, shift_count: 1, shift_slots: 3)
    end
    let!(:job3) do # 16 hours total
      create(:work_job, period: period, time_type: "date_only", hours: 2, shift_count: 2, shift_slots: 4)
    end

    context "with no shares" do
      it { is_expected.to be_zero }
    end

    context "with shares" do
      before do
        [1, 0, 1, 1, 0.5, 0.5].each_with_index { |p, i| period.shares.create!(user: users[i], portion: p) }
      end

      context "with no preassignments" do
        # (30 + 1.5 + 16) / 4
        it { is_expected.to be_within(0.01).of(11.88) }
      end

      context "with small preassignments" do
        let!(:job4) do # 4 hours
          create(:work_job, period: period, time_type: "date_only", hours: 4,
                            shift_count: 1, shift_slots: 1)
        end

        before do
          job1.shifts.first.assignments.create(user: users[4], preassigned: true)
          job4.shifts.first.assignments.create(user: users[0], preassigned: true)
        end

        # Preassigned: 4 + 3 = 7
        # Remaining: 27 + 1.5 + 16 = 44.5
        # Total: 78.5
        #
        #            Preass. hrs.     Round 1   2   3
        #
        # U0 (1.0x): 4                      4   6  19.75  <- Quota
        # U1 (0.0x):                        0   0   0     <- Zero
        # U2 (1.0x):                        4   6  12.88
        # U3 (1.0x):                        4   6  12.88
        # U4 (0.5x): 3                      3   3   6.44  <- Half-quota
        # U5 (0.5x):                        2   3   6.44  <- Half-quota
        #
        # Round 1: U2, U3 get 4 each, U5 gets 2, leaving 34.5
        # Round 2: U0, U2, U3 get 2 each, U5 gets 1, leaving 27.5
        # Round 3: U0, U2, U3 get 6.88, U4, U5 get 3.44, leaving 0
        it { is_expected.to be_within(0.01).of(12.88) }
      end

      context "with large preassignments" do
        let!(:job4) do # 25 hours
          create(:work_job, period: period, time_type: "date_only", hours: 25,
                            shift_count: 1, shift_slots: 1)
        end
        let!(:job5) do # 4 hours
          create(:work_job, period: period, time_type: "date_only", hours: 5,
                            shift_count: 1, shift_slots: 1)
        end
        let!(:job6) do # 1 hour
          create(:work_job, period: period, time_type: "date_only", hours: 1,
                            shift_count: 1, shift_slots: 1)
        end

        before do
          job1.shifts.first.assignments.create(user: users[0], preassigned: true)
          job3.shifts.first.assignments.create(user: users[3], preassigned: true)
          job4.shifts.first.assignments.create(user: users[0], preassigned: true)
          job5.shifts.first.assignments.create(user: users[4], preassigned: true)
          job6.shifts.first.assignments.create(user: users[5], preassigned: true)
        end

        context "with quota_type none" do
          let(:quota_type) { "none" }
          it { is_expected.to be_zero }
        end

        context "with quota_type by_person" do
          let(:quota_type) { "by_person" }

          # Preassigned: 3 + 2 + 25 + 5 + 1 = 36
          # Remaining: 27 + 1.5 + 14 = 42.5
          # Total: 78.5
          #
          #            Preass. hrs.     Round 1   2   3
          #
          # U0 (1.0x): 3, 25 = 2             28  28  28     <- Over-quota
          # U1 (0.0x):                        0   0   0     <- Zero
          # U2 (1.0x):                        2  10  16.83  <- Quota
          # U3 (1.0x): 2                      2  10  16.83
          # U4 (0.5x): 5                      5   5   8.42  <- Half-quota
          # U5 (0.5x): 1                      1   5   8.42  <- Half-quota
          #
          # Round 1: U2 gets 2, leaving 40.5
          # Round 2: U2, U3 get 8 each, U5 gets 4 leaving 20.5
          # Round 3: U2, U3 get 6.83 each, U4 gets 3.42, leaving 0
          it { is_expected.to be_within(0.01).of(16.83) }
        end

        context "with quota_type by_household" do
          let(:quota_type) { "by_household" }

          before do
            users[5].update!(household: users[0].household)
            users[2].update!(household: users[1].household)
            users[3].update!(household: users[1].household)
          end

          # Preassigned: 3 + 2 + 25 + 5 + 1 = 36
          # Remaining: 27 + 1.5 + 14 = 42.5
          # Total: 78.5
          #
          #            Preass. hrs.     Round 1   2     3
          #
          # H0 (1.5x): 3, 25, 1 = 29         29  29    29.48
          # H1 (2.0x): 2                     10  38.67 39.25 => Quota = 19.625
          # H4 (0.5x): 5                      5   9.67 9.81
          #
          # Round 1: H1 gets 8, leaving 34.5
          # Round 2: H1 gets 28.67, H4 gets 4.67, leaving 1.17
          # Round 3: Remainder is distributed
          it { is_expected.to be_within(0.01).of(19.63) }
        end
      end
    end
  end
end
