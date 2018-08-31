# frozen_string_literal: true

require "rails_helper"

describe Work::RoundCalculator do
  subject(:calculator) { described_class.new(target_share: target_share) }

  describe "next_num, prev_limit, next_limit" do
    let(:time) { "18:55" }
    let!(:shares) { portions.map { |p| create(:work_share, period: period, portion: p) } }
    let!(:zero_shares) { create_list(:work_share, 2, period: period, portion: 0) } # Should be ignored.
    let!(:assigns) do
      shares.each_with_index.map do |share, i|
        next if pre_assign_totals[i].zero?
        job = create(:work_job, period: period, hours: pre_assign_totals[i])
        create(:work_assignment, shift: job.shifts.first, user: share.user, preassigned: true)
      end
    end

    around do |example|
      Timecop.freeze("2018-08-15 #{time}") { example.run }
    end

    before do
      allow(period).to receive(:quota).and_return(17)
    end

    context "with lots of rounds" do
      # Pre  Prtn  Need   1  2  3  4  5  6  7  8  9 10
      # ----------------------------------------------
      #  0      1    17  11     5        0
      #  2      1    15  11     5        0
      #  2      1    15  11     5        0
      #  2      1    15     11     5        0
      #  6      1    11     11     5        0
      #  9      1     8     11     5        0
      #  9      1     8               5        0
      #  2    0.5   6.5               5        0
      # 11      1     3               5        0
      #  7    0.5   1.5                           0
      # 20      1    -3                           0
      # 20      1    -3                           0
      # 20      1    -3                              0
      # 20      1    -3                              0
      # 20      1    -3                              0
      let(:pre_assign_totals) { [0, 2, 2, 2, 2, 6, 7, 9, 9, 11, 20, 20, 20, 20, 20] }
      let(:portions) { [1, 1, 1, 0.5, 1, 1, 0.5, 1, 1, 1, 1, 1, 1, 1, 1] }
      let(:period) do
        create(:work_period, pick_type: "staggered", quota_type: "by_person", workers_per_round: 3,
                             round_duration: 5, max_rounds_per_worker: 3,
                             auto_open_time: Time.zone.parse("2018-08-15 19:00"))
      end

      context "worker with 0 hours" do
        let(:target_share) { shares[0] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:00"), limit: 6},
            {starts_at: Time.zone.parse("2018-08-15 19:10"), limit: 12},
            {starts_at: Time.zone.parse("2018-08-15 19:25"), limit: nil}
          ])
        end

        context "at time before auto open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: 6, next_starts_at: "19:00") }
        end

        context "at time within round 1" do
          let(:time) { "19:01" }
          it { expect_round(prev_limit: 6, next_limit: 12, next_starts_at: "19:10") }
        end

        context "at time within round 2" do
          let(:time) { "19:06" }
          it { expect_round(prev_limit: 6, next_limit: 12, next_starts_at: "19:10") }
        end

        context "at time within round 3" do
          let(:time) { "19:11" }
          it { expect_round(prev_limit: 12, next_limit: nil, next_starts_at: "19:25") }
        end

        context "at time within round 8" do
          let(:time) { "19:36" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_starts_at: nil) }
        end
      end

      context "worker with 2 hours, one of many, with large ID" do
        let(:target_share) { shares[1] }
        let(:time) { "18:55" }

        before do
          target_share.update!(id: 1e9)
        end

        it "should pick first in round 2" do
          expect_round(prev_limit: 0, next_limit: 6, next_starts_at: "19:05")
        end
      end

      context "worker with 11 hours" do
        let(:target_share) { shares[9] }

        context "at time before open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: 12, next_starts_at: "19:20") }
        end

        context "at time within round 3" do
          let(:time) { "19:11" }
          it { expect_round(prev_limit: 0, next_limit: 12, next_starts_at: "19:20") }
        end

        context "at time within round 5" do
          let(:time) { "19:21" }
          it { expect_round(prev_limit: 12, next_limit: nil, next_starts_at: "19:35") }
        end

        context "at time within round 8" do
          let(:time) { "19:36" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_starts_at: nil) }
        end

        context "at time within round 12" do
          let(:time) { "19:56" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_starts_at: nil) }
        end
      end

      context "worker with 2 hours, half share" do
        let(:target_share) { shares[3] }

        context "at time before open" do
          let(:time) { "18:55" }
          # (17 / 2 - 5.66).ceil => 3
          it { expect_round(prev_limit: 0, next_limit: 3, next_starts_at: "19:20") }
        end

        context "at time within round 5" do
          let(:time) { "19:21" }
          it { expect_round(prev_limit: 3, next_limit: nil, next_starts_at: "19:35") }
        end

        context "at time within round 8" do
          let(:time) { "19:36" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_starts_at: nil) }
        end
      end

      context "worker with more preassigned hours than quota" do
        let(:target_share) { shares[13] }

        it "has correct round schedule" do
          expect(calculator.rounds).to eq([
            {starts_at: Time.zone.parse("2018-08-15 19:45"), limit: nil}
          ])
        end

        context "at time before open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: nil, next_starts_at: "19:45") }
        end

        context "at time within round 8" do
          let(:time) { "19:36" }
          it { expect_round(prev_limit: 0, next_limit: nil, next_starts_at: "19:45") }
        end

        context "at time within round 10" do
          let(:time) { "19:46" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_starts_at: nil) }
        end
      end
    end

    context "with one round per worker" do
      # Pre  Prtn  Need   1  2  3  4  5  6  7  8  9 10
      # ---------------------------------------------------
      #   0     1    17   0
      #   2     1    15   0
      #   6     1    11      0
      #   7     1    10      0
      let(:pre_assign_totals) { [0, 2, 6, 7] }
      let(:portions) { [1, 1, 1, 1] }
      let(:period) do
        create(:work_period, pick_type: "staggered", quota_type: "by_person", workers_per_round: 2,
                             round_duration: 5, max_rounds_per_worker: 1,
                             auto_open_time: Time.zone.parse("2018-08-15 19:00"))
      end

      context "worker with low hours" do
        let(:target_share) { shares[1] }

        context "at time before open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: nil, next_starts_at: "19:00") }
        end

        context "at time within round 1" do
          let(:time) { "19:01" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_starts_at: nil) }
        end

        context "at time within round 2" do
          let(:time) { "19:06" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_starts_at: nil) }
        end
      end

      context "worker with higher hours" do
        let(:target_share) { shares[3] }

        context "at time before open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: nil, next_starts_at: "19:05") }
        end

        context "at time within round 1" do
          let(:time) { "19:01" }
          it { expect_round(prev_limit: 0, next_limit: nil, next_starts_at: "19:05") }
        end

        context "at time within round 2" do
          let(:time) { "19:06" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_starts_at: nil) }
        end
      end
    end

    context "with one large group" do
      # Pre  Prtn  Need   1  2  3  4  5  6  7  8  9 10
      # ---------------------------------------------------
      #   0     1    17   8  0
      #   2     1    15   8  0
      #   6     1    11   8  0
      #   7     1    10   8  0
      let(:pre_assign_totals) { [0, 2, 6, 7] }
      let(:portions) { [1, 1, 1, 1] }
      let(:period) do
        create(:work_period, pick_type: "staggered", quota_type: "by_person", workers_per_round: 100,
                             round_duration: 5, max_rounds_per_worker: 2,
                             auto_open_time: Time.zone.parse("2018-08-15 19:00"))
      end

      let(:target_share) { shares[1] }

      context "at time before open" do
        let(:time) { "18:55" }
        it { expect_round(prev_limit: 0, next_limit: 9, next_starts_at: "19:00") }
      end

      context "at time within round 1" do
        let(:time) { "19:01" }
        it { expect_round(prev_limit: 9, next_limit: nil, next_starts_at: "19:05") }
      end

      context "at time within round 2" do
        let(:time) { "19:06" }
        it { expect_round(prev_limit: nil, next_limit: nil, next_starts_at: nil) }
      end
    end

    def expect_round(prev_limit:, next_limit:, next_starts_at:)
      next_starts_at = Time.zone.parse("2018-08-15 #{next_starts_at}") unless next_starts_at.nil?
      expect(calculator.prev_limit).to eq(prev_limit)
      expect(calculator.next_limit).to eq(next_limit)
      expect(calculator.next_starts_at).to eq(next_starts_at)
    end
  end
end
