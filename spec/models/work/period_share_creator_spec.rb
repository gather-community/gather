require "rails_helper"

describe Work::PeriodShareCreator do
  let!(:period) { create(:work_period) }
  let!(:adult1) { create(:user) }
  let!(:adult2) { create(:user) }
  let!(:adult3) { create(:user) }
  let!(:child) { create(:user, :child, birthdate: Date.today - 10.years, guardians: [adult1]) }
  let!(:infant) { create(:user, :child, birthdate: Date.today - 1.years, guardians: [adult2]) }
  let!(:inactive) { create(:user, :inactive) }
  let!(:preexisting) { create(:work_share, user: adult3, period: period) }
  let(:shares_by_user_id) { period.shares.index_by(&:user_id) }

  it "creates shares for active users and children over min age" do
    described_class.new(period).create
    expect(period.reload.shares.map(&:user_id)).to contain_exactly(adult1.id, adult2.id, adult3.id, child.id)
    expect(shares_by_user_id[adult1.id].portion).to eq 1
    expect(shares_by_user_id[child.id].portion).to eq 0
  end
end
