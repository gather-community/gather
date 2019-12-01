# frozen_string_literal: true

require "rails_helper"
require "fileutils"

describe Utils::Generators::MainGenerator do
  before do
    FileUtils.rm_rf(Rails.root.join("public", "system", "test"))
  end

  # Don't delay jobs so that any mails would get sent immediately
  it "should run and destroy cleanly", :without_tenant, :perform_jobs do
    cluster = nil

    expect do
      cluster = described_class.new(
        cmty_name: "Foo Community",
        slug: "foo",
        sample_data: true,
        photos: true
      ).generate
    end.to change { ActionMailer::Base.deliveries.size }.by(0)

    expect(Cluster.count).to eq(1)

    ActsAsTenant.with_tenant(cluster) do
      # Check creation
      expect(Community.find_by(name: "Default")).to be_nil # Default cmty in factories should never be used.
      expect(Community.count).to eq(1)
      community = cluster.communities[0]
      expect(cluster.name).to eq("Foo Community")
      expect(community.name).to eq("Foo Community")
      expect(User.with_role(:admin).count).to be_zero
      expect(User.with_role(:super_admin).count).to be_zero
      expect(User.count).to be > 10
      expect(ActiveStorage::Blob.count).to be > 10

      # Destroy and check
      Utils::DataRemover.new(cluster.id).remove
      community.destroy
      Cluster.cluster_based_models.each do |klass|
        expect(klass.count).to eq(0), "Expected to find no #{klass.name.pluralize}"
      end
      expect(ActiveStorage::Blob.count).to eq(0)
    end
  end
end
