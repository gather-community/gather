# frozen_string_literal: true

require "rails_helper"

describe DomainPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { community }

    permissions :attach_to? do
      shared_examples_for "permits cluster admins but not admins or regular users" do
        it do
          expect(subject).to permit(cluster_admin, record)
          expect(subject).not_to permit(admin, record)
          expect(subject).not_to permit(user, record)
        end
      end

      context "domain belonging only to own community" do
        let(:record) { create(:domain, communities: [community]) }

        it "permits admins and regular users" do
          expect(subject).to permit(admin, record)
          expect(subject).to permit(user, record)
        end
      end

      context "domain belonging only to other community in cluster" do
        let(:record) { create(:domain, communities: [communityB]) }
        it_behaves_like "permits cluster admins but not admins or regular users"
      end

      context "domain belonging to both own community other community in cluster" do
        let(:record) { create(:domain, communities: [community, communityB]) }
        it_behaves_like "permits cluster admins but not admins or regular users"
      end
    end
  end
end
