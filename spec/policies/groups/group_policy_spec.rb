# frozen_string_literal: true

require "rails_helper"

describe Groups::GroupPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:availability) { "open" }
    let(:group) { create(:group, availability: availability, communities: [community, communityC]) }
    let(:record) { group }

    shared_examples_for "permits active admins in group's communities but not regular users" do
      it "permits only admins in the group's communities" do
        expect(subject).not_to permit(user, group)
        expect(subject).to permit(admin, group)
        expect(subject).not_to permit(admin_cmtyB, group)
      end

      it "forbids inactive admins" do
        expect(subject).not_to permit(inactive_admin, group)
      end

      it "permits cluster admins in any community in cluster" do
        expect(subject).to permit(cluster_admin_cmtyB, group)
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

        it "permits cluster admins in any community in cluster" do
          expect(subject).to permit(cluster_admin_cmtyB, group)
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

    permissions :destroy? do
      it_behaves_like "permits active admins in group's communities but not regular users"
    end
  end
end
