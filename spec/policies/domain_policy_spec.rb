# frozen_string_literal: true

require "rails_helper"

describe DomainPolicy do
  describe "permissions" do
    include_context "policy permissions"

    context "single community domain" do
      let(:record) { create(:domain, communities: [community]) }

      permissions :index?, :show?, :new?, :create?, :destroy? do
        it_behaves_like "permits admins from community"
      end

      permissions :edit?, :update? do
        it_behaves_like "forbids all"
      end

      permissions :destroy? do
        context "with existing mailman list" do
          let!(:list) { create(:group_mailman_list, domain: record) }
          it_behaves_like "forbids all"
        end
      end
    end

    context "multi-community domain" do
      let(:record) { create(:domain, communities: [community, communityB]) }

      permissions :show? do
        it "permits admins from community" do
          expect(subject).to permit(admin, record)
        end

        it "permits admins from communityB" do
          expect(subject).to permit(admin_cmtyB, record)
        end

        it "forbids admins from communityC" do
          expect(subject).not_to permit(admin_cmtyC, record)
        end
      end

      permissions :destroy? do
        it_behaves_like "permits cluster admins only"
      end

      permissions :edit?, :update? do
        it_behaves_like "forbids all"
      end
    end

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

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Domain }
    let!(:cluster_domain) { create(:domain, communities: [communityB]) }
    let!(:cmty_domain) { create(:domain, communities: [community, communityB]) }

    context "for cluster admin" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(cluster_domain, cmty_domain) }
    end

    context "for admin" do
      let(:actor) { admin }
      it { is_expected.to contain_exactly(cmty_domain) }
    end

    context "for regular user" do
      let(:actor) { user }
      it { is_expected.to be_empty }
    end

    context "for inactive user" do
      let(:actor) { inactive_user }
      it { is_expected.to be_empty }
    end
  end

  describe "permitted attributes" do
    include_context "policy permissions"

    let(:base_attribs) { %i[name] }
    let(:domain) { create(:domain) }
    subject { DomainPolicy.new(actor, domain).permitted_attributes }

    before { domain.reload unless domain.new_record? }

    context "with super admin" do
      let(:actor) { super_admin }
      it { is_expected.to match_array(base_attribs << {community_ids: []}) }
    end

    context "with cluster admin" do
      let(:actor) { cluster_admin }
      it { is_expected.to match_array(base_attribs << {community_ids: []}) }
    end

    context "with admin" do
      let(:actor) { admin }
      it { is_expected.to match_array(base_attribs) }
    end
  end
end
