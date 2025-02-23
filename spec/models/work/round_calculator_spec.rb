# frozen_string_literal: true

require "rails_helper"

describe Work::RoundCalculator do
  subject(:calculator) { described_class.new(target_share: target_share) }

  describe "next_num, prev_limit, next_limit" do
    let(:time) { "18:55" }
    let(:priority) { [] }
    let!(:shares) do
      portions.each_with_index.map do |portion, i|
        create(:work_share, period: period, portion: portion, priority: priority[i] == true)
      end
    end
    let!(:zero_shares) { create_list(:work_share, 2, period: period, portion: 0) } # Should be ignored.
    let!(:assigns) do
      shares.each_with_index.map do |share, i|
        next if pre_assign_totals[i].zero?

        job = create(:work_job, period: period, hours: pre_assign_totals[i])
        create(:work_assignment, shift: job.shifts.first, user: share.user, preassigned: true)
      end
    end

    around do |example|
      # Go to the 14th, on which everything gets 'set up'. The auto_open_time is set for the 15th at 7pm.
      Timecop.freeze("2018-08-14 12:00") { example.run }
    end

    before do
      allow(period).to receive(:quota).and_return(quota)
    end

    context "with lots of rounds" do
      # Quota: 19.3
      # Max rounds per worker: 3
      # Implied round max: 11.12
      # For given worker:
      #   Num rounds: ceil(Need / round max)
      #   Hours per round: Need / Num rounds
      #
      # Basic algorithm:
      #   At each round, sort the shares non-overachiever shares by:
      #   1. Rounds completed (ascending)
      #   2. Remaining need (descending)
      #   3. ID (ascending)
      #   and pick the top N
      # Idx   Pre  Prtn  Need      1    2    3    4    5    6    7    8    9
      # --------------------------------------------------------------------
      #  0     0      1    19.3  12.8            6.4            0
      #  1     2      1    17.3  11.5            5.8            0
      #  2     2      1    17.3  11.5                 5.8            0
      #  3     2      1    17.3       11.5            5.8            0
      #  4     7      1    12.3        6.2            0
      #  5     9      1    10.3        5.2                 0
      #  6    10      1     9.3             4.7            0
      #  7     2      0.5   7.7             3.8            0
      #  8    12.5    1     6.8             3.4                 0
      #  9     3      0.25  1.8                  0
      # 10    20      1    -0.7                                            0  At this point we can let all the
      # 11    20      1    -0.7                                            0  overachievers pick more jobs if
      # 12    20      1    -0.7                                            0  they want. There is no need to
      # 13    21      1    -1.7                                            0  count workers per round.
      # 14    21      1    -1.7                                            0

      # rubocop:disable Layout/ExtraSpacing
      let(:pre_assign_totals) { [0, 2, 2, 2, 6, 9, 10,   2, 12.5,    3, 20, 20, 20, 21, 21] }
      let(:portions) {          [1, 1, 1, 1, 1, 1,  1, 0.5,    1, 0.25,  1,  1,  1,  1,  1] }
      # rubocop:enable Layout/ExtraSpacing

      let(:quota) { 19.3 }
      let(:period) do
        create(:work_period, pick_type: "staggered", quota_type: "by_person", workers_per_round: 3,
                             round_duration: 5, max_rounds_per_worker: 3,
                             auto_open_time: Time.zone.parse("2018-08-15 19:00"))
      end

      context "worker with 0 preassigned hours" do
        let(:target_share) { shares[0] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:00"), limit: 7},
            {starts_at: Time.zone.parse("2018-08-15 19:15"), limit: 13},
            {starts_at: Time.zone.parse("2018-08-15 19:30"), limit: nil}
          ])
        end

        context "at time before auto open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: 7, next_starts_at: "19:00") }
        end

        context "at time within round 1" do
          let(:time) { "19:01" }
          it { expect_round(prev_limit: 7, next_limit: 13, next_starts_at: "19:15") }
        end

        context "at time within round 2" do
          let(:time) { "19:06" }
          it { expect_round(prev_limit: 7, next_limit: 13, next_starts_at: "19:15") }
        end

        context "at time within round 4" do
          let(:time) { "19:16" }
          it { expect_round(prev_limit: 13, next_limit: nil, next_starts_at: "19:30") }
        end

        context "at time right before round 7" do
          let(:time) { "19:29" }
          it { expect_round(prev_limit: 13, next_limit: nil, next_starts_at: "19:30") }
        end

        context "at time within round 7" do
          let(:time) { "19:31" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_starts_at: nil) }
        end
      end

      context "worker with 2 preassigned hours, one of many, with large ID" do
        let(:target_share) { shares[3] }

        before do
          target_share.update!(id: 1e9)
        end

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:05"), limit: 8},
            {starts_at: Time.zone.parse("2018-08-15 19:20"), limit: 14},
            {starts_at: Time.zone.parse("2018-08-15 19:35"), limit: nil}
          ])
        end
      end

      context "worker with 9 preassigned hours" do
        let(:target_share) { shares[5] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:05"), limit: 15},
            {starts_at: Time.zone.parse("2018-08-15 19:25"), limit: nil}
          ])
        end
      end

      context "worker with 2 preassigned hours, half share" do
        let(:target_share) { shares[7] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:10"), limit: 6},
            {starts_at: Time.zone.parse("2018-08-15 19:25"), limit: nil}
          ])
        end
      end

      context "worker with 12.5 preassigned hours" do
        let(:target_share) { shares[8] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:10"), limit: 16},
            {starts_at: Time.zone.parse("2018-08-15 19:30"), limit: nil}
          ])
        end
      end

      context "worker with 3 preassigned hours, quarter share" do
        let(:target_share) { shares[9] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:15"), limit: nil}
          ])
        end
      end

      context "worker with more preassigned hours than quota" do
        let(:target_share) { shares[13] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:40"), limit: nil}
          ])
        end
      end
    end

    context "with one round per worker" do
      # Pre  Prtn  Need     1  2  3  4  5  6  7  8  9 10
      # ---------------------------------------------------
      #   0     1    17.9   0
      #   2     1    15.9   0
      #   6     1    11.9      0
      #   7     1    10.9      0
      let(:pre_assign_totals) { [0, 2, 6, 7] }
      let(:portions) { [1, 1, 1, 1] }
      let(:quota) { 17.9 }
      let(:period) do
        create(:work_period, pick_type: "staggered", quota_type: "by_person", workers_per_round: 2,
                             round_duration: 5, max_rounds_per_worker: 1,
                             auto_open_time: Time.zone.parse("2018-08-15 19:00"))
      end

      context "worker with low preassigned hours" do
        let(:target_share) { shares[1] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:00"), limit: nil}
          ])
        end
      end

      context "worker with higher preassigned hours" do
        let(:target_share) { shares[3] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:05"), limit: nil}
          ])
        end
      end
    end

    context "with workers with priority" do
      # Pre  Prtn  Need  Pri  1  2  3  4  5  6  7  8  9 10
      # -------------------------------------------------------
      #   0  0.25  4.25    Y  0
      #  18     1    -1    Y  0
      #   6     1    11       5  0
      #   7     1    10          5  0
      #   7     1    10          5  0
      let(:pre_assign_totals) { [0, 18, 6, 7, 7] }
      let(:portions) { [0.25, 1, 1, 1, 1] }
      let(:priority) { [true, true, false, false, false] }
      let(:quota) { 17 }
      let(:period) do
        create(:work_period, pick_type: "staggered", quota_type: "by_person", workers_per_round: 3,
                             round_duration: 5, max_rounds_per_worker: 2,
                             auto_open_time: Time.zone.parse("2018-08-15 19:00"))
      end

      context "worker 0" do
        let(:target_share) { shares[0] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:00"), limit: nil}
          ])
        end
      end

      context "worker 1" do
        let(:target_share) { shares[1] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:00"), limit: nil}
          ])
        end
      end

      context "worker 2" do
        let(:target_share) { shares[2] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:00"), limit: 12},
            {starts_at: Time.zone.parse("2018-08-15 19:05"), limit: nil}
          ])
        end
      end

      context "worker 3" do
        let(:target_share) { shares[3] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:05"), limit: 12},
            {starts_at: Time.zone.parse("2018-08-15 19:10"), limit: nil}
          ])
        end
      end

      context "worker 4" do
        let(:target_share) { shares[4] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:05"), limit: 12},
            {starts_at: Time.zone.parse("2018-08-15 19:10"), limit: nil}
          ])
        end
      end
    end

    context "with one large group" do
      # Pre  Prtn  Need   1  2  3  4  5  6  7  8  9 10
      # ---------------------------------------------------
      #   0     1    17   8  0
      #   2     1    15   7  0
      #   6     1    11   5  0
      #   7     1    10   5  0
      let(:pre_assign_totals) { [0, 2, 6, 7] }
      let(:portions) { [1, 1, 1, 1] }
      let(:quota) { 17 }
      let(:period) do
        create(:work_period, pick_type: "staggered", quota_type: "by_person", workers_per_round: 100,
                             round_duration: 5, max_rounds_per_worker: 2,
                             auto_open_time: Time.zone.parse("2018-08-15 19:00"))
      end

      let(:target_share) { shares[1] }

      it "has correct round schedule" do
        expect(calculator.rounds).to eq([
          {starts_at: Time.zone.parse("2018-08-15 19:00"), limit: 10},
          {starts_at: Time.zone.parse("2018-08-15 19:05"), limit: nil}
        ])
      end
    end

    # This should not be possible unless all jobs have zero hours. But to test just in case.
    context "with zero quota" do
      # Pre  Prtn  Need   1  2  3  4  5  6  7  8  9 10
      # ---------------------------------------------------
      #   0     1     0   0
      #   2     1     0   0
      #   6     1     0   0
      #   7     1     0   0
      let(:pre_assign_totals) { [0, 2, 6, 7] }
      let(:portions) { [1, 1, 1, 1] }
      let(:quota) { 0 }
      let(:period) do
        create(:work_period, pick_type: "staggered", quota_type: "by_person", workers_per_round: 2,
                             round_duration: 5, max_rounds_per_worker: 2,
                             auto_open_time: Time.zone.parse("2018-08-15 19:00"))
      end

      context "worker in first group" do
        let(:target_share) { shares[1] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:00"), limit: nil}
          ])
        end
      end

      context "worker in second group" do
        let(:target_share) { shares[3] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:00"), limit: nil}
          ])
        end
      end
    end

    def expect_round(prev_limit:, next_limit:, next_starts_at:)
      Timecop.freeze("2018-08-15 #{time}") do
        next_starts_at = Time.zone.parse("2018-08-15 #{next_starts_at}") unless next_starts_at.nil?
        expect(calculator.prev_limit).to eq(prev_limit)
        expect(calculator.next_limit).to eq(next_limit)
        expect(calculator.next_starts_at).to eq(next_starts_at)
      end
    end
  end
end
