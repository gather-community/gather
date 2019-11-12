# frozen_string_literal: true

require "rails_helper"

describe "admin hierarchy" do
  let(:clusterA) { create(:cluster) }
  let(:clusterB) { create(:cluster) }
  let(:cmtyA1) { with_tenant(clusterA) { create(:community) } }
  let(:cmtyA2) { with_tenant(clusterA) { create(:community) } }
  let(:cmtyB) { with_tenant(clusterB) { create(:community) } }
  let(:recordA) { double(community: cmtyA2) }
  let(:recordB) { double(community: cmtyB) }
  let(:recordC) { double(community: nil) }

  shared_examples_for "admin for class and scope" do
    context "default" do
      it "should error unless user is superadmin" do
        unless user.global_role?(:super_admin)
          expect { ApplicationPolicy.new(user, Object).send(:active_admin?) }.to raise_error(
            ApplicationPolicy::CommunityNotSetError
          )
        end
      end
    end

    context "when allowing class-based auth" do
      let(:policy) { ApplicationPolicy.new(user, Object) }

      before do
        allow(policy).to receive(:allow_class_based_auth?).and_return(true)
      end

      it "should be admin for class" do
        expect(policy.send(:active_admin?)).to be(true)
      end
    end

    it "should be admin for scope" do
      expect(ApplicationPolicy::Scope.new(user, nil).send(:active_admin?)).to be(true)
    end
  end

  describe "cluster_admin" do
    let(:user) { create(:cluster_admin, household: create(:household, community: cmtyA1)) }

    it_behaves_like "admin for class and scope"

    it "should be be admin for record in different community but same cluster" do
      expect(ApplicationPolicy.new(user, recordA).send(:active_admin?)).to be(true)
    end

    it "should not be admin for record outside cluster" do
      expect(ApplicationPolicy.new(user, recordB).send(:active_admin?)).to be(false)
    end

    it "should raise error if record has no community set" do
      expect { ApplicationPolicy.new(user, recordC).send(:active_admin?) }.to raise_error(
        ApplicationPolicy::CommunityNotSetError
      )
    end
  end

  describe "super_admin" do
    let(:user) { create(:super_admin, household: create(:household, community: cmtyA1)) }

    it_behaves_like "admin for class and scope"

    it "should be be admin for record in same cluster" do
      expect(ApplicationPolicy.new(user, recordA).send(:active_admin?)).to be(true)
    end

    it "should be be admin for record in different cluster" do
      expect(ApplicationPolicy.new(user, recordB).send(:active_admin?)).to be(true)
    end
  end
end
