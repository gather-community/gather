# frozen_string_literal: true

require "rails_helper"

describe Groups::GroupPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:availability) { "open" }
    let(:communities) { [community, communityC] }
    let(:group) { create(:group, availability: availability, communities: communities) }
    let(:record) { group }

    shared_examples_for "permits active admins in group's communities but not regular users" do
      context "with single-community group" do
        let(:communities) { [community] }

        it "permits admin in community" do
          expect(subject).to permit(admin, group)
        end

        it "forbids inactive admins" do
          expect(subject).not_to permit(inactive_admin, group)
        end

        it "permits cluster admins in any community in cluster" do
          expect(subject).to permit(cluster_admin_cmtyB, group)
        end
      end

      context "with multi-community group" do
        it "forbids regular admins" do
          expect(subject).not_to permit(admin, group)
        end

        it "permits cluster admins in any community in cluster" do
          expect(subject).to permit(cluster_admin_cmtyB, group)
        end
      end

      it "forbids regular users" do
        expect(subject).not_to permit(user, group)
        expect(subject).not_to permit(user_cmtyC, group)
      end
    end

    permissions :index? do
      it_behaves_like "permits active users only"
    end

    permissions :show? do
      context "for closed group" do
        let(:availability) { "closed" }

        it "permits users in any of the group's communities" do
          expect(subject).to permit(user, group)
          expect(subject).to permit(user_cmtyC, group)
          expect(subject).not_to permit(user_cmtyB, group)
        end
      end

      context "for hidden group" do
        let(:availability) { "hidden" }
        it_behaves_like "permits active admins in group's communities but not regular users"
      end
    end

    permissions :new?, :create? do
      it_behaves_like "permits active admins in group's communities but not regular users"
    end

    permissions :edit?, :update? do
      let!(:manager) { create(:group_membership, group: group, kind: "manager").user }
      let!(:member) { create(:group_membership, group: group, kind: "member").user }

      it_behaves_like "permits active admins in group's communities but not regular users"

      it "permits managers" do
        expect(subject).to permit(manager, group)
        expect(subject).not_to permit(member, group)
      end
    end

    permissions :deactivate?, :destroy? do
      it_behaves_like "permits active admins in group's communities but not regular users"
    end

    permissions :activate? do
      let(:group) { create(:group, :inactive, availability: availability, communities: communities) }
      it_behaves_like "permits active admins in group's communities but not regular users"
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Groups::Group }
    let!(:cluster_group) { create(:group, communities: [communityB]) }
    let!(:cmty_group) { create(:group, communities: [community, communityB]) }
    let!(:hidden_group) { create(:group, communities: [community], availability: "hidden") }

    context "for cluster admin" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(cluster_group, cmty_group, hidden_group) }
    end

    context "for admin" do
      let(:actor) { admin }
      it { is_expected.to contain_exactly(cmty_group, hidden_group) }
    end

    context "for regular user" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(cmty_group) }
    end

    context "for inactive user" do
      let(:actor) { inactive_user }
      it { is_expected.to be_empty }
    end
  end

  describe "permitted attributes" do
    include_context "policy permissions"

    let(:base_attribs) do
      %i[availability can_request_jobs description kind name] << {memberships_attributes: %i[kind user_id]}
    end
    let(:group) { create(:group) }
    subject { Groups::GroupPolicy.new(actor, group).permitted_attributes }

    context "with cluster admin" do
      let(:actor) { cluster_admin }
      it { is_expected.to match_array(base_attribs << {community_ids: []}) }
    end

    context "with admin" do
      let(:actor) { admin }
      it { is_expected.to match_array(base_attribs) }
    end

    context "with manager" do
      let(:actor) { create(:group_membership, group: group, kind: "manager").user }
      it { is_expected.to match_array(base_attribs) }
    end
  end
end
