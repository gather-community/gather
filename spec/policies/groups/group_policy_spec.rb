# frozen_string_literal: true

require "rails_helper"

describe Groups::GroupPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:availability) { "open" }
    let(:group) { create(:group, availability: availability, communities: [community, communityC]) }
    let(:record) { group }

    permissions :index? do
      it_behaves_like "permits active users only"
    end

    permissions :show? do
      context "for closed group" do
        let(:availability) { "closed" }

        it "allows users in any of the group's communities" do
          expect(subject).to permit(user, group)
          expect(subject).to permit(user_cmtyC, group)
          expect(subject).not_to permit(user_cmtyB, group)
        end

        it "allows cluster admins in any community in cluster" do
          expect(subject).to permit(cluster_admin_cmtyB, group)
        end
      end

      context "for hidden group" do
        let(:availability) { "hidden" }

        it "allows only admins in the group's communities" do
          expect(subject).not_to permit(user, group)
          expect(subject).to permit(admin, group)
          expect(subject).not_to permit(admin_cmtyB, group)
        end

        it "allows cluster admins in any community in cluster" do
          expect(subject).to permit(cluster_admin_cmtyB, group)
        end
      end
    end
  end
end
