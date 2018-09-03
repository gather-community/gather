# frozen_string_literal: true

# Objects and examples useful for testing policy permissions.
shared_context "policy permissions" do
  subject(:policy) { described_class }
  let(:cluster) { default_cluster }
  let(:clusterB) { create(:cluster, name: "Other Cluster") }
  let(:community) { build(:community, name: "Community A") }
  let(:communityB) { build(:community, name: "Community B") }
  let(:communityC) { build(:community, name: "Community C") }
  let(:communityX) { with_tenant(clusterB) { build(:community, name: "Community X") } }

  let(:user) { new_user_from(community, label: "user") }
  let(:other_user) { new_user_from(community, label: "other_user") }
  let(:user_in_cmtyB) { new_user_from(communityB, label: "user_in_cmtyB") }
  let(:user_in_cmtyC) { new_user_from(communityC, label: "user_in_cmtyC") }
  let(:outside_user) { with_tenant(clusterB) { new_user_from(communityX, label: "outside_user") } }
  let(:inactive_user) { new_user_from(community, deactivated_at: Time.current, label: "inactive_user") }

  let(:household) { build(:household, users: [user], community: community) }
  let(:inactive_household) do
    build(:household, users: [inactive_user],
                      deactivated_at: Time.current, community: community)
  end
  let(:account) { build(:account, household: build(:household, community: community)) }

  let(:guardian) { user }
  let(:child) { new_user_from(community, child: true, guardians: [guardian], label: "child") }
  let(:other_child) { new_user_from(community, child: true, guardians: [other_user], label: "other_child") }
  let(:child_in_cmtyB) do
    new_user_from(communityB, child: true,
                              guardians: [user_in_cmtyB], label: "child_in_cmtyB")
  end
  let(:outside_child) do
    with_tenant(clusterB) do
      new_user_from(communityX, child: true,
                                guardians: [outside_user], label: "outside_child")
    end
  end
  let(:inactive_child) do
    new_user_from(community, child: true, guardians: [inactive_user],
                             deactivated_at: Time.current, label: "inactive_child")
  end

  let(:admin) { new_user_from(community, label: "admin") }
  let(:admin2) { new_user_from(community, label: "admin2") }
  let(:cluster_admin) { new_user_from(community, label: "cluster_admin") }
  let(:cluster_admin2) { new_user_from(community, label: "cluster_admin2") }
  let(:super_admin) { new_user_from(community, label: "super_admin") }
  let(:super_admin2) { new_user_from(community, label: "super_admin2") }
  let(:outside_cluster_admin) { new_user_from(community, label: "outside_cluster_admin") }
  let(:outside_super_admin) do
    with_tenant(clusterB) do
      new_user_from(communityX, label: "outside_super_admin")
    end
  end
  let(:admin_in_cmtyB) { new_user_from(communityB, label: "admin_in_cmtyB") }

  let(:biller) { new_user_from(community, label: "biller") }
  let(:biller_in_cmtyB) { new_user_from(communityB, label: "biller_in_cmtyB") }

  let(:photographer) { new_user_from(community, label: "photographer") }
  let(:photographer_in_cmtyB) { new_user_from(communityB, label: "photographer_in_cmtyB") }

  let(:meals_coordinator) { new_user_from(community, label: "meals_coordinator") }
  let(:meals_coordinator_in_cmtyB) { new_user_from(communityB, label: "meals_coordinator_in_cmtyB") }

  let(:work_coordinator) { new_user_from(community, label: "work_coordinator") }
  let(:work_coordinator_in_cmtyB) { new_user_from(communityB, label: "work_coordinator_in_cmtyB") }

  let(:wikiist) { new_user_from(community, label: "wikiist") }
  let(:wikiist_in_cmtyB) { new_user_from(communityB, label: "wikiist_in_cmtyB") }

  before do
    allow(user).to receive(:global_role?) { false }
    allow(other_user).to receive(:global_role?) { false }
    allow(admin).to receive(:global_role?) { |r| r == :admin }
    allow(admin2).to receive(:global_role?) { |r| r == :admin }
    allow(admin_in_cmtyB).to receive(:global_role?) { |r| r == :admin }
    allow(cluster_admin).to receive(:global_role?) { |r| r == :cluster_admin }
    allow(super_admin).to receive(:global_role?) { |r| r == :super_admin }
    allow(outside_cluster_admin).to receive(:global_role?) { |r| r == :cluster_admin }
    allow(outside_super_admin).to receive(:global_role?) { |r| r == :super_admin }
    allow(biller).to receive(:global_role?) { |r| r == :biller }
    allow(biller_in_cmtyB).to receive(:global_role?) { |r| r == :biller }
    allow(photographer).to receive(:global_role?) { |r| r == :photographer }
    allow(photographer_in_cmtyB).to receive(:global_role?) { |r| r == :photographer }
    allow(meals_coordinator).to receive(:global_role?) { |r| r == :meals_coordinator }
    allow(meals_coordinator_in_cmtyB).to receive(:global_role?) { |r| r == :meals_coordinator }
    allow(work_coordinator).to receive(:global_role?) { |r| r == :work_coordinator }
    allow(work_coordinator_in_cmtyB).to receive(:global_role?) { |r| r == :work_coordinator }
    allow(wikiist).to receive(:global_role?) { |r| r == :wikiist }
    allow(wikiist_in_cmtyB).to receive(:global_role?) { |r| r == :wikiist }
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

  shared_examples_for "permits cluster and super admins" do
    it "permits cluster admins from cluster" do
      expect(subject).to permit(outside_cluster_admin, record)
    end

    it "permits outside super admins" do
      expect(subject).to permit(outside_super_admin, record)
    end
  end

  shared_examples_for "permits users in community" do
    it_behaves_like "permits cluster and super admins"

    it "permits users in community" do
      expect(subject).to permit(user, record)
    end
  end

  shared_examples_for "permits users in community only" do
    it_behaves_like "permits users in community"

    it "forbids users from other communities" do
      expect(subject).not_to permit(user_in_cmtyB, record)
    end
  end

  shared_examples_for "permits users in cluster" do
    it_behaves_like "permits users in community"

    it "permits users from other communities in cluster" do
      expect(subject).to permit(user_in_cmtyB, record)
    end

    it "forbids users from communities outside cluster" do
      expect(subject).not_to permit(outside_user, record)
    end
  end

  shared_examples_for "permits admins from community" do
    context do
      let(:actor) { admin }
      it_behaves_like "errors on permission check without community"
    end
    it_behaves_like "permits cluster and super admins"

    it "permits admins from community" do
      expect(subject).to permit(admin, record)
    end

    it "forbids admins from outside community" do
      expect(subject).not_to permit(admin_in_cmtyB, record)
    end
  end

  shared_examples_for "permits admins but not regular users" do
    it_behaves_like "permits admins from community"

    it "forbids regular user" do
      expect(subject).not_to permit(user, record)
    end
  end

  shared_examples_for "permits active users only" do
    it "permits active users" do
      expect(subject).to permit(user, record)
    end

    it "forbids inactive users" do
      expect(subject).not_to permit(inactive_user, record)
    end
  end

  shared_examples_for "permits special role but not regular users" do |role_name|
    context do
      let(:actor) { role_member(role_name) }
      it_behaves_like "errors on permission check without community"
    end

    it "forbids regular user" do
      expect(subject).not_to permit(user, record)
    end

    it "permits role from community" do
      expect(subject).to permit(role_member(role_name), record)
    end

    it "forbids role from outside community" do
      expect(subject).not_to permit(role_member("#{role_name}_in_cmtyB"), record)
    end
  end

  shared_examples_for "permits admins or special role but not regular users" do |role_name|
    it_behaves_like "permits admins but not regular users"
    it_behaves_like "permits special role but not regular users", role_name
  end

  shared_examples_for "permits cluster admins only" do
    it "permits cluster admins" do
      expect(subject).to permit(cluster_admin, record)
      expect(subject).to permit(outside_cluster_admin, record)
    end

    it "forbids admins" do
      expect(subject).not_to permit(admin, record)
    end

    it "forbids regular users" do
      expect(subject).not_to permit(user, record)
    end

    it "forbids billers" do
      expect(subject).not_to permit(biller, record)
    end
  end

  shared_examples_for "permits self (active or not) and guardians" do
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

  shared_examples_for "forbids regular users" do
    it do
      expect(subject).not_to permit(user, record)
    end
  end

  shared_examples_for "forbids all" do
    it "doesn't permit super admins" do
      expect(subject).not_to permit(super_admin, record)
    end
  end

  # We know that checking the permission should check the community, so if there is nil community,
  # we should get an error!
  shared_examples_for "errors on permission check without community" do
    context "with nil community" do
      before { expect(record).to receive(:community).at_least(1).and_return(nil) }

      it "errors when checking role permission" do |example|
        example.metadata[:permissions].each do |perm|
          expect { subject.new(actor, record).send(perm) }.to raise_error(
            ApplicationPolicy::CommunityNotSetError
          )
        end
      end
    end
  end

  def role_member(role_name)
    send(role_name)
  end

  def new_user_from(community, attribs = {})
    build(:user, attribs.merge(
      first_name: attribs.delete(:label).capitalize.tr("_", " "),
      community: community
    ))
  end
end
