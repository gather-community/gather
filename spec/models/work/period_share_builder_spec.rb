# frozen_string_literal: true

require "rails_helper"

describe Work::PeriodShareBuilder do
  let!(:adult1) { create(:user) }
  let!(:adult2) { create(:user) }
  let!(:adult3) { create(:user) }
  let!(:child) { create(:user, :child, birthdate: Time.zone.today - 10.years, guardians: [adult1]) }
  let!(:infant) { create(:user, :child, birthdate: Time.zone.today - 1.year, guardians: [adult2]) }
  let!(:inactive) { create(:user, :inactive) }
  let(:shares_by_user_id) { period.shares.index_by(&:user_id) }

  before do
    described_class.new(period).build
  end

  shared_examples_for "builds shares with appropriate default portion" do
    it "builds shares for active users and children over min age" do
      expect(period.shares.map(&:user_id)).to contain_exactly(adult1.id, adult2.id, adult3.id, child.id)
    end

    it "builds shares with the appropriate default portion" do
      expect(shares_by_user_id[adult1.id].portion).to eq(1)
      expect(shares_by_user_id[child.id].portion).to eq(0)
    end
  end

  context "with new period" do
    let(:quota_type) { "by_household" }
    let(:period) { build(:work_period, quota_type: quota_type) }
    it_behaves_like "builds shares with appropriate default portion"
  end

  context "with existing period and preexisting share" do
    let(:period) { create(:work_period, quota_type: quota_type) }
    let!(:preexisting) { create(:work_share, user: adult3, period: period) }

    context "with none quota type" do
      let(:quota_type) { "none" }
      it_behaves_like "builds shares with appropriate default portion"
    end

    context "with by_household quota type" do
      let(:quota_type) { "by_household" }

      it "builds shares for active users and children over min age" do
        expect(period.shares.map(&:user_id)).to contain_exactly(adult1.id, adult2.id, adult3.id, child.id)
      end

      it "builds shares with nil portion" do
        expect(shares_by_user_id[adult1.id].portion).to be_nil
        expect(shares_by_user_id[child.id].portion).to be_nil
      end
    end
  end
end
