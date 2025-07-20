# frozen_string_literal: true

# Objects and examples useful for testing policy permissions.
shared_context "policy permissions" do
  subject(:policy) { described_class }

  # These have !s because they are always needed and we want them to be created first.
  let!(:cluster) { Defaults.cluster }
  let!(:community) { Defaults.community }

  let(:clusterB) { create(:cluster, name: "Other Cluster") }
  let(:communityB) { create(:community, name: "Community B") }
  let(:communityC) { create(:community, name: "Community C") }
  let(:communityX) { with_tenant(clusterB) { create(:community, name: "Community X") } }
  let(:user) { create(:user, first_name: "user") }
  let(:other_user) { create(:user, first_name: "other_user") }
  let(:user_cmtyB) { create(:user, community: communityB, first_name: "user_cmtyB") }
  let(:user_cmtyC) { create(:user, community: communityC, first_name: "user_cmtyC") }
  let(:user_cmtyX) do
    with_tenant(clusterB) { create(:user, community: communityX, first_name: "user_cmtyX") }
  end
  let(:inactive_user) { create(:user, deactivated_at: Time.current, first_name: "inactive_user") }
  let(:household) { create(:household, users: [user], community: community) }
  let(:inactive_household) do
    create(:household, users: [inactive_user],
                       deactivated_at: Time.current, community: community)
  end
  let(:account) { create(:household, community: community).accounts[0] }
  let(:guardian) { user }
  let(:child) { create(:user, :child, guardians: [guardian], first_name: "child") }
  let(:full_access_child) { create(:user, :full_access_child, guardians: [guardian], first_name: "fachild") }
  let(:other_child) { create(:user, :child, guardians: [other_user], first_name: "other_child") }
  let(:child_cmtyB) do
    create(:user, :child, community: communityB, guardians: [user_cmtyB], first_name: "child_cmtyB")
  end
  let(:child_cmtyX) do
    with_tenant(clusterB) do
      create(:user, :child, community: communityX, guardians: [user_cmtyX], first_name: "child_cmtyX")
    end
  end
  let(:inactive_child) do
    create(:user, :child, :inactive, guardians: [inactive_user], first_name: "inactive_child")
  end
  let(:admin) { create(:admin, first_name: "admin") }
  let(:admin2) { create(:admin, first_name: "admin2") }
  let(:cluster_admin) { create(:cluster_admin, first_name: "cluster_admin") }
  let(:cluster_admin2) { create(:cluster_admin, first_name: "cluster_admin2") }
  let(:cluster_admin_cmtyB) do
    create(:cluster_admin, community: communityB, first_name: "cluster_admin_cmtyB")
  end
  let(:cluster_admin_cmtyX) do
    create(:cluster_admin, community: communityB, first_name: "cluster_admin_cmtyX")
  end
  let(:super_admin) { create(:super_admin, first_name: "super_admin") }
  let(:super_admin2) { create(:super_admin, first_name: "super_admin2") }
  let(:super_admin_cmtyX) do
    with_tenant(clusterB) do
      create(:super_admin, community: communityX, first_name: "super_admin_cmtyX")
    end
  end
  let(:admin_cmtyB) { create(:admin, community: communityB, first_name: "admin_cmtyB") }
  let(:admin_cmtyC) { create(:admin, community: communityC, first_name: "admin_cmtyC") }
  let(:inactive_admin) { create(:admin, :inactive, first_name: "inactive_admin") }
  let(:biller) { create(:biller, first_name: "biller") }
  let(:biller_cmtyB) { create(:biller, community: communityB, first_name: "biller_cmtyB") }
  let(:photographer) { create(:photographer, first_name: "photographer") }
  let(:photographer_cmtyB) { create(:photographer, community: communityB, first_name: "photographer_cmtyB") }
  let(:calendar_coordinator) { create(:calendar_coordinator, first_name: "calendar_coord") }
  let(:calendar_coordinator_cmtyB) do
    create(:calendar_coordinator, community: communityB, first_name: "calendar_coord_cmtyB")
  end
  let(:meals_coordinator) { create(:meals_coordinator, first_name: "meals_coord") }
  let(:meals_coordinator_cmtyB) do
    create(:meals_coordinator, community: communityB, first_name: "meals_coord_cmtyB")
  end
  let(:work_coordinator) { create(:work_coordinator, first_name: "work_coordinator") }
  let(:work_coordinator_cmtyB) do
    create(:work_coordinator, community: communityB, first_name: "work_coordinator_cmtyB")
  end
  let(:wikiist) { create(:wikiist, first_name: "wikiist") }
  let(:wikiist_cmtyB) { create(:wikiist, community: communityB, first_name: "wikiist_cmtyB") }

  shared_examples_for "permits super admins only" do
    it "forbids cluster admins from cluster" do
      expect(subject).not_to permit(cluster_admin_cmtyX, record)
    end

    it "permits outside super admins" do
      expect(subject).to permit(super_admin_cmtyX, record)
    end
  end

  shared_examples_for "permits cluster and super admins" do
    it "permits cluster admins from cluster" do
      expect(subject).to permit(cluster_admin_cmtyX, record)
    end

    it "permits outside super admins" do
      expect(subject).to permit(super_admin_cmtyX, record)
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
      user_cmtyB.community
      expect(subject).not_to permit(user_cmtyB, record)
    end
  end

  shared_examples_for "permits users in cluster" do
    it_behaves_like "permits users in community"

    it "permits users from other communities in cluster" do
      expect(subject).to permit(user_cmtyB, record)
    end

    it "forbids users from communities outside cluster" do
      expect(subject).not_to permit(user_cmtyX, record)
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
      expect(subject).not_to permit(admin_cmtyB, record)
    end
  end

  shared_examples_for "permits admins from any community" do
    context do
      let(:actor) { admin }
      it_behaves_like "errors on permission check without community"
    end
    it_behaves_like "permits cluster and super admins"

    it "permits admins from community" do
      expect(subject).to permit(admin, record)
    end

    it "permits admins from outside community" do
      expect(subject).to permit(admin_cmtyB, record)
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

  shared_examples_for "permits active and inactive users" do
    it "permits active users" do
      expect(subject).to permit(user, record)
    end

    it "permits inactive users" do
      expect(subject).to permit(inactive_user, record)
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
      expect(subject).not_to permit(role_member("#{role_name}_cmtyB"), record)
    end
  end

  shared_examples_for "permits admins or special role but not regular users" do |role_name|
    it_behaves_like "permits admins but not regular users"
    it_behaves_like "permits special role but not regular users", role_name
  end

  shared_examples_for "permits cluster admins only" do
    it "permits cluster admins" do
      expect(subject).to permit(cluster_admin, record)
      expect(subject).to permit(cluster_admin_cmtyX, record)
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

    it "permits guardians to edit own children" do
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
      before do
        if record.respond_to?(:community)
          expect(record).to receive(:community).at_least(1).and_return(nil)
        else
          expect(record).to receive(:communities).at_least(1).and_return([])
        end
      end

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
end
