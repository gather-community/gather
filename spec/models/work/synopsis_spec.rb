# frozen_string_literal: true

require "rails_helper"

describe Work::Synopsis do
  let(:user) { create(:user) }
  let(:user2) { create(:user, household: user.household) }
  let(:shares) { [1, 1] }
  let(:quota) { 23.4 }
  let(:quota_type) { "by_person" }
  let(:phase) { "open" }
  let(:period) do
    create(:work_period, quota_type: quota_type, quota: quota, phase: phase)
  end
  let!(:decoy_period) { create(:work_period) }
  let!(:decoy_job) { create(:work_job, period: decoy_period) }
  let!(:decoy_assign) { create(:work_assignment, shift: decoy_job.shifts.first, user: user) }
  let(:synopsis) { described_class.new(period: period, user: user) }
  let(:regular) { described_class::REGULAR_BUCKET }
  let(:for_user) { synopsis.for_user }
  let(:for_household) { synopsis.for_household }
  let(:staggering) { synopsis.staggering }
  let(:done) { synopsis.done? }

  before do
    period.shares.create!(user: user, portion: shares[0])
    period.shares.create!(user: user2, portion: shares[1])
  end

  let!(:regjob) { create(:work_job, period: period, hours: 3) }

  context "no quota" do
    let(:quota_type) { "none" }
    it { expect(synopsis).to be_empty }
  end

  context "period in draft phase" do
    let(:phase) { "draft" }
    it { expect(synopsis).to be_empty }
  end

  context "no share" do
    let(:shares) { [0, 1] }
    it { expect(synopsis).to be_empty }
  end

  context "by_person quota" do
    context "no full community jobs" do
      context "zero signups" do
        it do
          expect(for_user).to eq([{bucket: regular, got: 0, ttl: 23.4, ok: false}])
          expect(done).to be(false)
        end
      end

      context "with signup" do
        before { regjob.shifts.first.assignments.create!(user: user) }
        it do
          expect(for_user).to eq([{bucket: regular, got: 3.0, ttl: 23.4, ok: false}])
          expect(done).to be(false)
        end

        context "quota met" do
          let(:quota) { 2.91 }
          it do
            expect(for_user).to eq([{bucket: regular, got: 3.0, ttl: 2.91, ok: true}])
            expect(done).to be(true)
          end
        end
      end
    end

    context "with full community job" do
      let!(:fcjob) do
        create(:work_job, period: period, title: "Alpha", slot_type: "full_multiple",
                          hours: 6, shift_count: 2, shift_hours: [3, 3])
      end

      context "zero signups" do
        it do
          expect(for_user).to eq([{bucket: regular, got: 0, ttl: 23.4, ok: false},
                                  {bucket: fcjob, got: 0, ttl: 6, ok: false}])
          expect(done).to be(false)
        end
      end

      context "with signups" do
        let(:quota) { 2.91 }

        before do
          regjob.shifts.first.assignments.create!(user: user)
          fcjob.shifts.first.assignments.create!(user: user)
        end

        it do
          expect(for_user).to eq([{bucket: regular, got: 3, ttl: 2.91, ok: true},
                                  {bucket: fcjob, got: 3, ttl: 6, ok: false}])
          expect(done).to be(false)
        end

        context "all quotas met" do
          before { fcjob.shifts.last.assignments.create!(user: user) }
          it do
            expect(for_user).to eq([{bucket: regular, got: 3, ttl: 2.91, ok: true},
                                    {bucket: fcjob, got: 6, ttl: 6, ok: true}])
            expect(done).to be(true)
          end
        end

        context "with staggering" do
          let(:starts_at) { Time.current + 10.minutes }
          let(:round_calc) { double(prev_limit: 5, next_limit: 10, next_starts_at: starts_at) }

          before do
            allow(period).to receive(:staggered?).and_return(true)
            allow(Work::RoundCalculator).to receive(:new).and_return(round_calc)
          end

          it "includes round information" do
            expect(for_user).to eq([{bucket: regular, got: 3, ttl: 2.91, ok: true},
                                    {bucket: fcjob, got: 3, ttl: 6, ok: false}])
            expect(done).to be(false)
            expect(staggering).to eq(prev_limit: 5, next_limit: 10, next_starts_at: starts_at)
          end
        end
      end

      context "with another full community job" do
        let!(:fcjob2) do
          create(:work_job, period: period, title: "Bravo", slot_type: "full_multiple",
                            hours: 4, shift_count: 2, shift_hours: [2, 2])
        end

        it do
          expect(for_user).to eq([{bucket: regular, got: 0, ttl: 23.4, ok: false},
                                  {bucket: fcjob, got: 0, ttl: 6, ok: false},
                                  {bucket: fcjob2, got: 0, ttl: 4, ok: false}])
          expect(done).to be(false)
        end
      end
    end
  end

  context "by_household quota" do
    let(:quota_type) { "by_household" }
    let!(:fcjob) do
      create(:work_job, period: period, slot_type: "full_multiple",
                        hours: 6, shift_count: 2, shift_hours: [3, 3])
    end

    context "zero signups, 2 full shares" do
      let(:shares) { [1, 1] }
      it do
        expect(for_user).to eq([{bucket: regular, got: 0, ttl: 23.4, ok: false},
                                {bucket: fcjob, got: 0, ttl: 6, ok: false}])
        expect(for_household).to eq([{bucket: regular, got: 0, ttl: 46.8, ok: false},
                                     {bucket: fcjob, got: 0, ttl: 12, ok: false}])
        expect(done).to be(false)
      end
    end

    context "partially complete, 1.5 shares" do
      let(:shares) { [1, 0.5] }

      before do
        regjob.shifts.first.assignments.create!(user: user2)
        fcjob.shifts.first.assignments.create!(user: user)
        fcjob.shifts.last.assignments.create!(user: user)
      end

      it do
        expect(for_user).to eq([{bucket: regular, got: 0, ttl: 23.4, ok: false},
                                {bucket: fcjob, got: 6, ttl: 6, ok: true}])
        expect(for_household).to eq([{bucket: regular, got: 3, ttl: 35.1, ok: false},
                                     {bucket: fcjob, got: 6, ttl: 9, ok: false}])
        expect(done).to be(false)
      end

      context "household complete even though user not" do
        let(:quota) { 1.9 }

        before do
          fcjob.shifts.first.assignments.create!(user: user2)
        end

        it do
          expect(for_user).to eq([{bucket: regular, got: 0, ttl: 1.9, ok: true},
                                  {bucket: fcjob, got: 6, ttl: 6, ok: true}])
          expect(for_household).to eq([{bucket: regular, got: 3, ttl: 2.85, ok: true},
                                       {bucket: fcjob, got: 9, ttl: 9, ok: true}])
          expect(done).to be(true)
        end
      end
    end
  end
  # Users with no share of the workload still fall under the round schedule, so staggering has to be
  # computed for them even though they have no obligations to report.
  describe "staggering for a user with no share" do
    let(:staggered_period) do
      create(:work_period, quota_type: "by_person", quota: 23.4, phase: "open", pick_type: "staggered",
                           auto_open_time: Time.current - 1.minute, round_duration: 5,
                           max_rounds_per_worker: 3, workers_per_round: 10)
    end
    let(:synopsis) { described_class.new(period: staggered_period, user: user) }

    before { staggered_period.shares.create!(user: user2, portion: 1) }

    shared_examples_for "limit of zero until the final round" do
      it "reports no obligations but a limit of zero" do
        expect(synopsis).to be_empty
        expect(synopsis).to be_staggering
        expect(synopsis.staggering[:prev_limit]).to eq(0)
        expect(synopsis.staggering[:next_starts_at]).to be_present
      end

      it "lifts the limit once the final round starts" do
        staggered_period.update!(auto_open_time: Time.current - 1.day)
        expect(synopsis.staggering[:prev_limit]).to be_nil
      end
    end

    context "with no share row at all" do
      it_behaves_like "limit of zero until the final round"
    end

    context "with a share row of zero portion" do
      before { staggered_period.shares.create!(user: user, portion: 0) }
      it_behaves_like "limit of zero until the final round"
    end
  end
end
