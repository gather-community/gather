shared_context "policy objs" do
  subject { described_class }
  let(:community) { Community.new }
  let(:user) { User.new }
  let(:other_user) { User.new }
  let(:inactive_user) { User.new(deactivated_at: Time.now) }
  let(:household) { Household.new(users: [user], community: community) }
  let(:admin) { User.new(admin: true, household: Household.new(community: community)) }
  let(:biller) { User.new(biller: true, household: Household.new(community: community)) }
  let(:account) { Billing::Account.new }

  let(:outside_admin) { User.new(admin: true, household: Household.new) }
  let(:outside_biller) { User.new(biller: true, household: Household.new) }

  before do
    allow(user).to receive(:community).and_return(community)
    allow(inactive_user).to receive(:community).and_return(community)
    allow(admin).to receive(:community).and_return(community)
    allow(biller).to receive(:community).and_return(community)
    allow(account).to receive(:community).and_return(community)
  end
end
