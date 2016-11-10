shared_context "policy objs" do
  subject { described_class }
  let(:community) { Community.new }
  let(:user) { User.new }
  let(:other_user) { User.new }
  let(:inactive_user) { User.new(deactivated_at: Time.now) }
  let(:household) { Household.new(users: [user], community: community) }
  let(:admin) { User.new(household: Household.new(community: community)) }
  let(:biller) { User.new(household: Household.new(community: community)) }
  let(:account) { Billing::Account.new }

  let(:outside_admin) { User.new(household: Household.new) }
  let(:outside_biller) { User.new(household: Household.new) }

  before do
    allow(user).to receive(:community).and_return(community)
    allow(inactive_user).to receive(:community).and_return(community)
    allow(admin).to receive(:community).and_return(community)
    allow(admin).to receive(:has_role?) { |r| r == :admin }
    allow(biller).to receive(:community).and_return(community)
    allow(biller).to receive(:has_role?) { |r| r == :biller }
    allow(account).to receive(:community).and_return(community)
    allow(outside_admin).to receive(:has_role?) { |r| r == :admin }
    allow(outside_biller).to receive(:has_role?) { |r| r == :biller }
  end
end
