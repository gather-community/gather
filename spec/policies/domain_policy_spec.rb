# frozen_string_literal: true

require "rails_helper"

describe DomainPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { community }

    permissions :attach_to? do
      context "domain belonging to own community" do
        let(:record) { create(:domain, communities: [community]) }

        it "permits admins and regular users" do
          expect(subject).to permit(admin, record)
          expect(subject).to permit(user, record)
        end
      end

      context "domain belonging to other community in cluster" do
        let(:record) { create(:domain, communities: [communityB]) }

        it "permits cluster admins but not admins or regular users" do
          expect(subject).to permit(cluster_admin, record)
          expect(subject).not_to permit(admin, record)
          expect(subject).not_to permit(user, record)
        end
      end
    end
  end
end
