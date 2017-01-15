shared_context "policy objs" do
  subject { described_class }
  let(:cluster) { build(:cluster, name: "Main Cluster") }
  let(:clusterB) { build(:cluster, name: "Other Cluster") }
  let(:community) { build(:community, name: "Community A", cluster: cluster) }
  let(:communityB) { build(:community, name: "Community B", cluster: cluster) }
  let(:communityX) { build(:community, name: "Community X", cluster: clusterB) }
  let(:user) { new_user_from(community) }
  let(:other_user) { new_user_from(community) }
  let(:user_in_cluster) { new_user_from(communityB) }
  let(:outside_user) { new_user_from(communityX) }
  let(:inactive_user) { new_user_from(community, deactivated_at: Time.now) }
  let(:household) { build(:household, users: [user], community: community) }
  let(:account) { build(:account, household: build(:household, community: community)) }

  let(:guardian) { user }
  let(:child) { new_user_from(community, child: true, guardians: [guardian]) }
  let(:other_child) { new_user_from(community, guardians: [other_user]) }

  let(:admin) { new_user_from(community) }
  let(:cluster_admin) { new_user_from(community) }
  let(:super_admin) { new_user_from(community) }
  let(:admin_in_cluster) { new_user_from(communityB) }

  let(:biller) { new_user_from(community) }
  let(:biller_in_cluster) { new_user_from(communityB) }

  before do
    allow(user).to receive(:has_role?) { false }
    allow(other_user).to receive(:has_role?) { false }
    allow(admin).to receive(:has_role?) { |r| r == :admin }
    allow(cluster_admin).to receive(:has_role?) { |r| r == :cluster_admin }
    allow(super_admin).to receive(:has_role?) { |r| r == :super_admin }
    allow(biller).to receive(:has_role?) { |r| r == :biller }
    allow(admin_in_cluster).to receive(:has_role?) { |r| r == :admin }
    allow(biller_in_cluster).to receive(:has_role?) { |r| r == :biller }
  end

  # Saves commonly used objects from above. This is not done by default
  # to make specs faster where it is not needed.
  def save_policy_objects!
    [cluster, clusterB, community, communityB, communityX].each(&:save!)
    [user, admin, cluster_admin, super_admin].each do |u|
      u.household.community_id = u.household.community.id
      u.save!
    end
  end

  shared_examples_for "grants access to users in community" do
    it "grants access to users in community" do
      expect(subject).to permit(user, record)
    end

    it "denies access to users from other communities" do
      expect(subject).not_to permit(user_in_cluster, record)
    end
  end

  shared_examples_for "grants access to users in cluster" do
    it "grants access to users in community" do
      expect(subject).to permit(user, record)
    end

    it "grants access to users from other communities in cluster" do
      expect(subject).to permit(user_in_cluster, record)
    end

    it "denies access from users from communities outside cluster" do
      expect(subject).not_to permit(outside_user, record)
    end
  end

  shared_examples_for "admins only" do
    it "grants access to admins in community" do
      expect(subject).to permit(admin, record)
    end

    it "denies access to admins in other community in cluster" do
      expect(subject).not_to permit(admin_in_cluster, record)
    end

    it "denies access to regular users" do
      expect(subject).not_to permit(user, record)
    end

    it "denies access to billers" do
      expect(subject).not_to permit(biller, record)
    end
  end

  shared_examples_for "cluster admins only" do
    it "grants access to cluster admins" do
      expect(subject).to permit(cluster_admin, record)
    end

    it "denies access to admins" do
      expect(subject).not_to permit(admin, record)
    end

    it "denies access to regular users" do
      expect(subject).not_to permit(user, record)
    end

    it "denies access to billers" do
      expect(subject).not_to permit(biller, record)
    end
  end

  def new_user_from(community, attribs = {})
    build(:user, attribs.merge(household: build(:household, community: community)))
  end
end
