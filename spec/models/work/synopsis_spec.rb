# frozen_string_literal: true

require "rails_helper"

describe Work::Synopsis do
  let(:user) { create(:user) }
  let(:user2) { create(:user, household: user.household) }
  let(:shares) { [1, 1] }
  let(:quota) { 23.4 }
  let(:quota_type) { "by_person" }
  let(:phase) { "open" }
  let(:pick_type) { "free_for_all" }
  let(:period) do
    create(:work_period, quota_type: quota_type, quota: quota, phase: phase, pick_type: pick_type)
  end
  let!(:decoy_period) { create(:work_period) }
  let!(:decoy_job) { create(:work_job, period: decoy_period) }
  let!(:decoy_assign) { create(:work_assignment, shift: decoy_job.shifts.first, user: user) }
  let(:synopsis) { described_class.new(period: period, user: user) }
  let(:regular) { OpenStruct.new(title: I18n.t("work.synopsis.regular")) }
  subject { synopsis.data }

  before do
    allow(synopsis).to receive(:regular).and_return(regular)
    period.shares.create!(user: user, portion: shares[0])
    period.shares.create!(user: user2, portion: shares[1])
  end

  let!(:regjob) { create(:work_job, period: period, hours: 3) }

  context "no quota" do
    let(:quota_type) { "none" }
    it { is_expected.to be_nil }
  end

  context "period not open" do
    let(:phase) { "draft" }
    it { is_expected.to be_nil }
  end

  context "no share" do
    let(:shares) { [0, 1] }
    it { is_expected.to be_nil }
  end

  context "by_person quota" do
    context "no full community jobs" do
      context "zero signups" do
        it do
          is_expected.to eq(self: [{bucket: regular, got: 0, ttl: 23.4, ok: false}], done: false)
        end
      end

      context "with signup" do
        before { regjob.shifts.first.assignments.create!(user: user) }
        it do
          is_expected.to eq(self: [{bucket: regular, got: 3.0, ttl: 23.4, ok: false}], done: false)
        end

        context "quota met" do
          let(:quota) { 2.91 }
          it do
            is_expected.to eq(self: [{bucket: regular, got: 3.0, ttl: 2.91, ok: true}], done: true)
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
          is_expected.to eq(self: [{bucket: regular, got: 0, ttl: 23.4, ok: false},
                                   {bucket: fcjob, got: 0, ttl: 6, ok: false}],
                            done: false)
        end
      end

      context "with signups" do
        let(:quota) { 2.91 }

        before do
          regjob.shifts.first.assignments.create!(user: user)
          fcjob.shifts.first.assignments.create!(user: user)
        end

        it do
          is_expected.to eq(self: [{bucket: regular, got: 3, ttl: 2.91, ok: true},
                                   {bucket: fcjob, got: 3, ttl: 6, ok: false}],
                            done: false)
        end

        context "all quotas met" do
          before { fcjob.shifts.last.assignments.create!(user: user) }
          it do
            is_expected.to eq(self: [{bucket: regular, got: 3, ttl: 2.91, ok: true},
                                     {bucket: fcjob, got: 6, ttl: 6, ok: true}],
                              done: true)
          end
        end

        context "with staggering" do
          let(:pick_type) { "staggered" }
          let(:starts_at) { Time.current + 10.minutes }
          let(:round_calc) { double(prev_limit: 5, next_limit: 10, next_starts_at: starts_at) }

          before do
            allow(Work::RoundCalculator).to receive(:new).and_return(round_calc)
          end

          it "includes round information" do
            is_expected.to eq(self: [{bucket: regular, got: 3, ttl: 2.91, ok: true},
                                     {bucket: fcjob, got: 3, ttl: 6, ok: false}],
                              done: false,
                              staggering: {prev_limit: 5, next_limit: 10, next_starts_at: starts_at})
          end
        end
      end

      context "with another full community job" do
        let!(:fcjob2) do
          create(:work_job, period: period, title: "Bravo", slot_type: "full_multiple",
                            hours: 4, shift_count: 2, shift_hours: [2, 2])
        end

        it do
          is_expected.to eq(self: [{bucket: regular, got: 0, ttl: 23.4, ok: false},
                                   {bucket: fcjob, got: 0, ttl: 6, ok: false},
                                   {bucket: fcjob2, got: 0, ttl: 4, ok: false}],
                            done: false)
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
        is_expected.to eq(self:      [{bucket: regular, got: 0, ttl: 23.4, ok: false},
                                      {bucket: fcjob, got: 0, ttl: 6, ok: false}],
                          household: [{bucket: regular, got: 0, ttl: 46.8, ok: false},
                                      {bucket: fcjob, got: 0, ttl: 12, ok: false}],
                          done:      false)
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
        is_expected.to eq(self:      [{bucket: regular, got: 0, ttl: 23.4, ok: false},
                                      {bucket: fcjob, got: 6, ttl: 6, ok: true}],
                          household: [{bucket: regular, got: 3, ttl: 35.1, ok: false},
                                      {bucket: fcjob, got: 6, ttl: 9, ok: false}],
                          done:      false)
      end

      context "household complete even though user not" do
        let(:quota) { 1.9 }

        before do
          fcjob.shifts.first.assignments.create!(user: user2)
        end

        it do
          is_expected.to eq(self:      [{bucket: regular, got: 0, ttl: 1.9, ok: true},
                                        {bucket: fcjob, got: 6, ttl: 6, ok: true}],
                            household: [{bucket: regular, got: 3, ttl: 2.85, ok: true},
                                        {bucket: fcjob, got: 9, ttl: 9, ok: true}],
                            done:      true)
        end
      end
    end
  end
end
