# frozen_string_literal: true

require "rails_helper"

describe Work::RoundLimitChecker do
  let(:user) { create(:user) }
  let(:pick_type) { "staggered" }
  let(:slot_type) { "fixed" }
  let(:prev_limit) { 5 }
  let(:round_calc) { double(prev_limit: prev_limit, next_limit: nil, next_starts_at: nil) }
  let(:period) do
    create(:work_period, phase: "open", quota_type: "by_person", quota: 20, pick_type: pick_type,
                         auto_open_time: Time.current - 1.hour, round_duration: 5,
                         max_rounds_per_worker: 3, workers_per_round: 10)
  end
  let(:job) { create(:work_job, period: period, hours: 3, slot_type: slot_type) }
  let(:shift) { job.shifts.first }

  subject(:exceeded) { described_class.new(shift: shift, user: user).exceeded? }

  before do
    period.shares.create!(user: user, portion: 1)
    allow(Work::RoundCalculator).to receive(:new).and_return(round_calc)
  end

  context "with a free for all period" do
    let(:pick_type) { "free_for_all" }
    let(:prev_limit) { 0 }

    it "never applies, and doesn't bother building a synopsis" do
      expect(Work::Synopsis).not_to receive(:new)
      expect(exceeded).to be(false)
    end
  end

  context "with a full community job" do
    let(:slot_type) { "full_single" }
    let(:prev_limit) { 0 }
    it { is_expected.to be(false) }
  end

  context "with no limit in force" do
    let(:prev_limit) { nil }
    it { is_expected.to be(false) }
  end

  context "with the shift fitting inside the limit" do
    let(:prev_limit) { 3 }
    it { is_expected.to be(false) }
  end

  context "with the shift exceeding the limit" do
    let(:prev_limit) { 2 }
    it { is_expected.to be(true) }
  end

  context "with hours already taken in the period" do
    let(:prev_limit) { 5 }
    let!(:other_job) { create(:work_job, period: period, hours: 4) }
    before { other_job.shifts.first.assignments.create!(user: user) }

    it "counts them toward the limit" do
      # 4 already taken + 3 for this shift = 7, over the limit of 5.
      expect(exceeded).to be(true)
    end
  end

  # This one runs against the real RoundCalculator, since the whole point is what schedule a user
  # with no share of their own ends up on.
  context "with a user who has no share in the period" do
    let!(:sharer) { create(:user) }

    before do
      allow(Work::RoundCalculator).to receive(:new).and_call_original
      period.shares.where(user: user).destroy_all
      period.shares.create!(user: sharer, portion: 1)
      period.update!(auto_open_time: Time.current - 1.minute)
    end

    it "holds them to a limit of zero until the rounds are done" do
      expect(exceeded).to be(true)
    end

    context "once the final round has started" do
      before { period.update!(auto_open_time: Time.current - 1.day) }
      it { is_expected.to be(false) }
    end
  end

  describe "synopsis handling" do
    let(:prev_limit) { 2 }

    context "with a synopsis for the shift's own period" do
      let(:synopsis) { Work::Synopsis.new(period: period, user: user) }

      it "uses the one it was given" do
        checker = described_class.new(shift: shift, user: user, synopsis: synopsis)
        expect(Work::Synopsis).not_to receive(:new)
        expect(checker.exceeded?).to be(true)
      end
    end

    context "with a synopsis for some other period" do
      let(:other_period) { create(:work_period, phase: "open") }
      let(:wrong_synopsis) { double(period: other_period, "staggering?": false) }

      it "discards it and builds one for the shift's period" do
        checker = described_class.new(shift: shift, user: user, synopsis: wrong_synopsis)
        expect(checker.exceeded?).to be(true)
      end
    end
  end
end
