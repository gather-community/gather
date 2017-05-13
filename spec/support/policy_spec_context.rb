shared_context "policy objs" do
  subject { described_class }
  let(:cluster) { default_cluster }
  let(:clusterB) { create(:cluster, name: "Other Cluster") }
  let(:community) { build(:community, name: "Community A") }
  let(:communityB) { build(:community, name: "Community B") }
  let(:communityX) { with_tenant(clusterB) { build(:community, name: "Community X") } }

  let(:user) { new_user_from(community, label: "user") }
  let(:other_user) { new_user_from(community, label: "other_user") }
  let(:user_in_cluster) { new_user_from(communityB, label: "user_in_cluster") }
  let(:outside_user) { with_tenant(clusterB) { new_user_from(communityX, label: "outside_user") } }
  let(:inactive_user) { new_user_from(community, deactivated_at: Time.now, label: "inactive_user") }

  let(:household) { build(:household, users: [user], community: community) }
  let(:inactive_household) { build(:household, users: [inactive_user],
    deactivated_at: Time.now, community: community) }
  let(:account) { build(:account, household: build(:household, community: community)) }

  let(:guardian) { user }
  let(:child) { new_user_from(community, child: true, guardians: [guardian], label: "child") }
  let(:other_child) { new_user_from(community, child: true, guardians: [other_user], label: "other_child") }
  let(:child_in_cluster) { new_user_from(communityB, child: true,
    guardians: [user_in_cluster], label: "child_in_cluster") }
  let(:outside_child) { with_tenant(clusterB) { new_user_from(communityX, child: true,
    guardians: [outside_user], label: "outside_child") } }
  let(:inactive_child) { new_user_from(community, child: true, guardians: [inactive_user],
    deactivated_at: Time.now, label: "inactive_child") }

  let(:admin) { new_user_from(community, label: "admin") }
  let(:cluster_admin) { new_user_from(community, label: "cluster_admin") }
  let(:super_admin) { new_user_from(community, label: "super_admin") }
  let(:outside_super_admin) { with_tenant(clusterB) {
    new_user_from(communityX, label: "outside_super_admin") } }
  let(:admin_in_cluster) { new_user_from(communityB, label: "admin_in_cluster") }

  let(:biller) { new_user_from(community, label: "biller") }
  let(:biller_in_cluster) { new_user_from(communityB, label: "biller_in_cluster") }

  let(:photographer) { new_user_from(community, label: "photographer") }
  let(:photographer_in_cluster) { new_user_from(communityB, label: "photographer_in_cluster") }

  let(:meals_coordinator) { new_user_from(community, label: "meals_coordinator") }

  before do
    allow(user).to receive(:has_role?) { false }
    allow(other_user).to receive(:has_role?) { false }
    allow(admin).to receive(:has_role?) { |r| r == :admin }
    allow(admin_in_cluster).to receive(:has_role?) { |r| r == :admin }
    allow(cluster_admin).to receive(:has_role?) { |r| r == :cluster_admin }
    allow(super_admin).to receive(:has_role?) { |r| r == :super_admin }
    allow(outside_super_admin).to receive(:has_role?) { |r| r == :super_admin }
    allow(biller).to receive(:has_role?) { |r| r == :biller }
    allow(biller_in_cluster).to receive(:has_role?) { |r| r == :biller }
    allow(photographer).to receive(:has_role?) { |r| r == :photographer }
    allow(photographer_in_cluster).to receive(:has_role?) { |r| r == :photographer }
    allow(meals_coordinator).to receive(:has_role?) { |r| r == :meals_coordinator }
  end

  # Saves commonly used objects from above. This is not done by default
  # to make specs faster where it is not needed.
  def save_policy_objects!(*objs)
    objs.each do |obj|
      # If we don't do this it doesn't save correctly.
      obj.household.community_id = obj.household.community.id if obj.is_a?(User)
      if obj.respond_to?(:cluster)
        with_tenant(obj.cluster) { obj.save! }
      else
        obj.save!
      end
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

    it "denies access to users from communities outside cluster" do
      expect(subject).not_to permit(outside_user, record)
    end
  end

  shared_examples_for "permits for commmunity admins and denies for other admins, users, and billers" do
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

  shared_examples_for "permits for self (active or not) and guardians" do
    it "permits action on self" do
      expect(subject).to permit(user, user)
    end

    it "allows guardians to edit own children" do
      expect(subject).to permit(guardian, child)
    end

    it "disallows guardians from editing other children" do
      expect(subject).not_to permit(guardian, other_child)
    end

    it "disallows children from editing parent" do
      expect(subject).not_to permit(child, guardian)
    end

    it "permits action on self for inactive user" do
      expect(subject).to permit(inactive_user, inactive_user)
    end
  end

  shared_examples_for "permits for photographers in community only" do
    it "permits photographers from own community" do
      expect(subject).to permit(photographer, user)
    end

    it "denies photographers from other community" do
      expect(subject).not_to permit(photographer_in_cluster, user)
    end
  end

  shared_examples_for "permits admins or billers but not regular users" do
    it "grants access to admins from community" do
      expect(subject).to permit(admin, record)
    end

    it "grants access to billers from community" do
      expect(subject).to permit(admin, record)
    end

    it "denies access to admins from outside community" do
      expect(subject).not_to permit(admin_in_cluster, record)
    end

    it "denies access to billers from outside community" do
      expect(subject).not_to permit(biller_in_cluster, record)
    end

    it "errors when checking admin without community" do |example|
      example.metadata[:permissions].each do |perm|
        expect { subject.new(admin, record.class).send(perm) }.to raise_error(
          ApplicationPolicy::CommunityNotSetError)
      end
    end

    it "errors when checking biller without community" do |example|
      example.metadata[:permissions].each do |perm|
        expect { subject.new(biller, record.class).send(perm) }.to raise_error(
          ApplicationPolicy::CommunityNotSetError)
      end
    end

    it "denies access to regular user" do
      expect(subject).not_to permit(user, record)
    end
  end

  def new_user_from(community, attribs = {})
    build(:user, attribs.merge(
      first_name: attribs.delete(:label).capitalize.gsub("_", " "),
      community: community
    ))
  end
end
