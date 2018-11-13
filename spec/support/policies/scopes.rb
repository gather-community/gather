# frozen_string_literal: true

# Objects and examples useful for testing policy scopes.
shared_context "policy scopes" do
  let(:cluster) { default_cluster }
  let(:community) { default_community }
  let(:communityB) { create(:community, name: "Community B") }

  let(:user) { create(:user, community: community) }
  let(:other_user) { create(:user, community: community) }
  let(:inactive_user) { create(:user, :inactive, community: community) }
  let(:userB) { create(:user, community: communityB) }

  let(:method) { :resolve }
  subject(:permitted) { described_class::Scope.new(actor, klass.all).send(method) }

  User::ROLES.each do |role|
    let(role) { create(role, community: community) }
  end

  shared_examples_for "all cluster objects visible to cluster admin" do
    let(:actor) { cluster_admin }
    it { is_expected.to match_array(objs_in_community + objs_in_cluster) }
  end

  shared_examples_for "allows regular users in community" do
    it_behaves_like "all cluster objects visible to cluster admin"

    context "for regular users" do
      let(:actor) { user }
      it { is_expected.to match_array(objs_in_community) }
    end

    context "for inactive user" do
      let(:actor) { inactive_user }
      it { is_expected.to be_empty }
    end
  end

  shared_examples_for "allows only admins in community" do
    it_behaves_like "all cluster objects visible to cluster admin"

    context "for admins" do
      let(:actor) { admin }
      it { is_expected.to match_array(objs_in_community) }
    end

    context "for regular users" do
      let(:actor) { user }
      it { is_expected.to be_empty }
    end
  end

  shared_examples_for "allows only admins or special role in community" do |role|
    it_behaves_like "allows only admins in community"

    context "for special role" do
      let(:actor) { send(role) }
      it { is_expected.to match_array(objs_in_community) }
    end
  end

  shared_examples_for "allows all users in cluster" do
    context "for regular users" do
      let(:actor) { user }
      it { is_expected.to match_array(objs_in_community + objs_in_cluster) }
    end

    context "for inactive user" do
      let(:actor) { inactive_user }
      it { is_expected.to be_empty }
    end
  end
end
