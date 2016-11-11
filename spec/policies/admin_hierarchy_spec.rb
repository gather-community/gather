require "rails_helper"

describe "admin hierarchy" do
  let(:clusterA) { create(:cluster) }
  let(:clusterB) { create(:cluster) }
  let(:cmtyA1) { create(:community, cluster: clusterA) }
  let(:cmtyA2) { create(:community, cluster: clusterA) }
  let(:cmtyB) { create(:community, cluster: clusterB) }
  let(:recordA) { double(community: cmtyA2) }
  let(:recordB) { double(community: cmtyB) }

  shared_examples_for "admin for class and scope" do
    it "should be admin for class" do
      expect(ApplicationPolicy.new(user, Object).send(:active_admin?)).to be true
    end

    it "should be admin for scope" do
      expect(ApplicationPolicy::Scope.new(user, nil).send(:active_admin?)).to be true
    end
  end

  describe "cluster_admin" do
    let(:user) { create(:cluster_admin, household: create(:household, community: cmtyA1)) }

    it_behaves_like "admin for class and scope"

    it "should be be admin for record in different community but same cluster" do
      expect(ApplicationPolicy.new(user, recordA).send(:active_admin?)).to be true
    end

    it "should not be admin for record outside cluster" do
      expect(ApplicationPolicy.new(user, recordB).send(:active_admin?)).to be false
    end
  end

  describe "super_admin" do
    let(:user) { create(:super_admin, household: create(:household, community: cmtyA1)) }

    it_behaves_like "admin for class and scope"

    it "should be be admin for record in same cluster" do
      expect(ApplicationPolicy.new(user, recordA).send(:active_admin?)).to be true
    end

    it "should be be admin for record in different cluster" do
      expect(ApplicationPolicy.new(user, recordB).send(:active_admin?)).to be true
    end
  end
end
