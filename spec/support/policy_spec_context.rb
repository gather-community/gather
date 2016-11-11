shared_context "policy objs" do
  subject { described_class }
  let(:cluster) { Cluster.new(name: "Main Cluster") }
  let(:community) { Community.new(name: "Community A", cluster: cluster) }
  let(:communityB) { Community.new(name: "Community B", cluster: cluster) }
  let(:user) { new_user_from(community) }
  let(:other_user) { new_user_from(community) }
  let(:inactive_user) { new_user_from(community, deactivated_at: Time.now) }
  let(:household) { Household.new(users: [user], community: community) }
  let(:account) { Billing::Account.new(household: Household.new(community: community)) }

  let(:admin) { new_user_from(community) }
  let(:cluster_admin) { new_user_from(community) }
  let(:super_admin) { new_user_from(community) }
  let(:outside_admin) { new_user_from(communityB) }

  let(:biller) { new_user_from(community) }
  let(:outside_biller) { new_user_from(communityB) }

  before do
    allow(user).to receive(:has_role?) { false }
    allow(other_user).to receive(:has_role?) { false }
    allow(admin).to receive(:has_role?) { |r| r == :admin }
    allow(cluster_admin).to receive(:has_role?) { |r| r == :cluster_admin }
    allow(super_admin).to receive(:has_role?) { |r| r == :super_admin }
    allow(biller).to receive(:has_role?) { |r| r == :biller }
    allow(outside_admin).to receive(:has_role?) { |r| r == :admin }
    allow(outside_biller).to receive(:has_role?) { |r| r == :biller }
  end

  def new_user_from(community, attribs = {})
    User.new(attribs.merge(household: Household.new(community: community)))
  end
end
