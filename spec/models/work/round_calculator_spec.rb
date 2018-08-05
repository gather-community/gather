# frozen_string_literal: true

require "rails_helper"

describe Work::RoundCalculator do
  describe "#num and #hour_limit" do
    let!(:shares) { create_list(:work_share, pre_assign_totals.size, period: period) }
    let!(:zero_shares) { create_list(:work_share, 2, period: period, portion: 0) } # Should be ignored.
    let!(:assigns) do
      shares.each_with_index.map do |share, i|
        next if pre_assign_totals[i].zero?
        job = create(:work_job, period: period, hours: pre_assign_totals[i])
        create(:work_assignment, shift: job.shifts.first, user: share.user, preassigned: true)
      end
    end
    subject(:calculator) { described_class.new(share: target_share) }

    around do |example|
      Timecop.freeze("2018-08-15 #{time}") { example.run }
    end

    before do
      allow(period).to receive(:quota).and_return(18)
      shares.sample.update!(portion: 0.5) # Shouldn't affect calculations.
    end

    context "with lots of rounds" do
      # Start  1  2  3  4  5  6  7  8  9 10 11 12 13
      # ---------------------------------------------------
      #  0     5    10       15          ∞
      #  2     5    10       15          ∞
      #  2     5    10       15          ∞
      #  2        5    10       15          ∞
      #  2        5    10       15          ∞
      #  6             10       15          ∞
      #  7                10       15          ∞
      #  9                10       15          ∞
      #  9                10       15          ∞
      # 14                            15          ∞
      # 20                                        ∞
      let(:pre_assign_totals) { [0, 2, 2, 2, 2, 6, 7, 9, 9, 14, 20] }
      let(:period) do
        create(:work_period, quota_type: "by_person", workers_per_round: 3,
                             round_duration: 5.minutes, hours_per_round: 5,
                             auto_open_time: Time.zone.parse("2018-08-15 19:00"))
      end

      context "worker with zero hours" do
        let(:target_share) { shares[0] }

        context "at time before auto open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: 5, next_num: 1) }
        end

        context "at time within round 1" do
          let(:time) { "19:01" }
          it { expect_round(prev_limit: 5, next_limit: 10, next_num: 3) }
        end

        context "at time within round 2" do
          let(:time) { "19:06" }
          it { expect_round(prev_limit: 5, next_limit: 10, next_num: 3) }
        end

        context "at time within round 3" do
          let(:time) { "19:11" }
          it { expect_round(prev_limit: 10, next_limit: 15, next_num: 6) }
        end

        context "at time within round 8" do
          let(:time) { "19:36" }
          it { expect_round(prev_limit: 15, next_limit: nil, next_num: 10) }
        end

        context "at time within last round" do
          let(:time) { "19:46" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_num: nil) }
        end

        context "at time after last round" do
          let(:time) { "19:51" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_num: nil) }
        end
      end

      context "worker with two hours, one of many, with large ID" do
        let(:target_share) { shares[1] }
        let(:time) { "18:55" }

        before do
          target_share.update!(id: 1e9)
        end

        it "should pick first in round 2" do
          expect_round(prev_limit: 0, next_limit: 5, next_num: 2)
        end
      end

      context "worker with moderate hours" do
        let(:target_share) { shares[7] }

        context "at time before open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: 10, next_num: 5) }
        end

        context "at time within round 3" do
          let(:time) { "19:11" }
          it { expect_round(prev_limit: 0, next_limit: 10, next_num: 5) }
        end

        context "at time within round 5" do
          let(:time) { "19:21" }
          it { expect_round(prev_limit: 10, next_limit: 15, next_num: 8) }
        end

        context "at time within round 8" do
          let(:time) { "19:36" }
          it { expect_round(prev_limit: 15, next_limit: nil, next_num: 12) }
        end

        context "at time within round 12" do
          let(:time) { "19:56" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_num: nil) }
        end
      end

      context "worker with more preassigned hours than quota" do
        let(:target_share) { shares[10] }

        context "at time before open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: nil, next_num: 13) }
        end

        context "at time within round 8" do
          let(:time) { "19:36" }
          it { expect_round(prev_limit: 0, next_limit: nil, next_num: 13) }
        end

        context "at time within round 13" do
          let(:time) { "20:01" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_num: nil) }
        end
      end
    end

    context "with two rounds" do
      # Start  1  2  3  4  5  6  7  8  9 10 11 12 13
      # ---------------------------------------------------
      #  0     ∞
      #  2     ∞
      #  6        ∞
      #  7        ∞
      let(:pre_assign_totals) { [0, 2, 6, 7] }
      let(:period) do
        create(:work_period, quota_type: "by_person", workers_per_round: 2,
                             round_duration: 5.minutes, hours_per_round: 20,
                             auto_open_time: Time.zone.parse("2018-08-15 19:00"))
      end

      context "worker with low hours" do
        let(:target_share) { shares[1] }

        context "at time before open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: nil, next_num: 1) }
        end

        context "at time within round 1" do
          let(:time) { "19:01" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_num: nil) }
        end

        context "at time within round 2" do
          let(:time) { "19:06" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_num: nil) }
        end
      end

      context "worker with higher hours" do
        let(:target_share) { shares[3] }

        context "at time before open" do
          let(:time) { "18:55" }
          it { expect_round(prev_limit: 0, next_limit: nil, next_num: 2) }
        end

        context "at time within round 1" do
          let(:time) { "19:01" }
          it { expect_round(prev_limit: 0, next_limit: nil, next_num: 2) }
        end

        context "at time within round 2" do
          let(:time) { "19:06" }
          it { expect_round(prev_limit: nil, next_limit: nil, next_num: nil) }
        end
      end
    end

    def expect_round(prev_limit:, next_limit:, next_num:)
      expect(calculator.prev_limit).to eq(prev_limit)
      expect(calculator.next_limit).to eq(next_limit)
      expect(calculator.next_num).to eq(next_num)
    end
  end
end
