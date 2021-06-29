# frozen_string_literal: true

require "rails_helper"

describe Work::PeriodCloner do
  let(:inactive_user) { create(:user, :inactive) }
  let!(:old_period) do
    create(:work_period, name: "My Period",
                         starts_on: "2020-01-01",
                         ends_on: "2020-03-31",
                         phase: "archived",
                         auto_open_time: "2019-11-05 14:30",
                         pick_type: "staggered",
                         quota_type: "by_person",
                         round_duration: 5,
                         max_rounds_per_worker: 3,
                         workers_per_round: 10)
  end
  let!(:old_shares) do
    [
      create(:work_share, period: old_period, portion: 1),
      create(:work_share, period: old_period, portion: 0.5),
      create(:work_share, period: old_period, portion: 1, user: inactive_user)
    ]
  end
  let!(:new_period) { Work::Period.new }
  subject(:cloner) { described_class.new(old_period: old_period, new_period: new_period) }

  describe "#copy_attributes_and_shares" do
    it "works" do
      cloner.copy_attributes_and_shares
      expect(new_period.name).to be_nil
      expect(new_period.starts_on).to be_nil
      expect(new_period.ends_on).to be_nil
      expect(new_period.phase).to eq("draft")
      expect(new_period.auto_open_time).to be_nil
      expect(new_period.pick_type).to eq("staggered")
      expect(new_period.quota_type).to eq("by_person")
      expect(new_period.quota).to eq(0.0)
      expect(new_period.round_duration).to eq(5)
      expect(new_period.max_rounds_per_worker).to eq(3)
      expect(new_period.workers_per_round).to eq(10)

      expect(new_period.shares.size).to eq(2)
      expect(new_period.shares[0].portion).to eq(1)
      expect(new_period.shares[0].user_id).to eq(old_shares[0].user_id)
      expect(new_period.shares[1].portion).to eq(0.5)
      expect(new_period.shares[1].user_id).to eq(old_shares[1].user_id)
    end
  end
end
