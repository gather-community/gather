# frozen_string_literal: true

require "rails_helper"
require "fileutils"

# Don't delay jobs so that any mails would get sent immediately
describe Utils::Generators::MainGenerator, :without_tenant, :perform_jobs do
  before do
    FileUtils.rm_rf(Rails.root.join("public", "system", "test"))
  end

  it "should run and destroy cleanly with sample data" do
    cluster = nil

    expect do
      main = described_class.new(cmty_name: "Foo Community", slug: "foo", sample_data: true, photos: true)
      cluster = main.generate
    end.to change { ActionMailer::Base.deliveries.size }.by(0)

    ActsAsTenant.with_tenant(cluster) do
      check_cmty_and_cluster_creation(cluster)
      expect_no_admins

      # Check counts of key classes to ensure sub generators are being called.
      # Detailed counts should be checked in generator specs.
      expect(User.count).to be > 12
      expect(Groups::Group.count).to be > 1
      expect(Meals::Meal.count).to be > 1
      expect(Reservations::Reservation.count).to be > 1
      expect(Reservations::Resource.count).to be > 1
      expect(Billing::Statement.count).to be > 1

      # Ensure photos are generated.
      expect(ActiveStorage::Blob.count).to be > 12

      # Destroy and check
      Utils::DataRemover.new(cluster.id).remove
      cluster.communities[0].destroy
      Cluster.cluster_based_models.each do |klass|
        expect(klass.count).to eq(0), "Expected to find no #{klass.name.pluralize}"
      end
      expect(ActiveStorage::Blob.count).to eq(0)
    end
  end

  it "should run and destroy cleanly without sample data" do
    cluster = described_class.new(cmty_name: "Foo Community", slug: "foo", sample_data: false).generate

    ActsAsTenant.with_tenant(cluster) do
      check_cmty_and_cluster_creation(cluster)
      expect_no_admins

      # Check counts of key classes to ensure sub generators are being called.
      # Detailed counts should be checked in generator specs.
      expect(User.count).to eq(0)
      expect(Groups::Group.count).to eq(1) # Everybody group
      expect(Meals::Meal.count).to eq(0)
      expect(Meals::Formula.count).to eq(1) # Default formula
      expect(Meals::Role.count).to eq(3) # Default roles
      expect(Reservations::Reservation.count).to eq(0)
      expect(Reservations::Resource.count).to eq(0)
      expect(Billing::Statement.count).to eq(0)
      expect(ActiveStorage::Blob.count).to eq(0)
    end
  end

  def check_cmty_and_cluster_creation(cluster)
    expect(Cluster.count).to eq(1)
    expect(cluster.name).to eq("Foo Community")
    expect(Community.find_by(name: "Default")).to be_nil # Default cmty in factories should never be used.
    expect(Community.count).to eq(1)
    expect(cluster.communities[0].name).to eq("Foo Community")
  end

  def expect_no_admins
    # Admins are generated separately.
    expect(User.with_role(:admin).count).to be_zero
    expect(User.with_role(:super_admin).count).to be_zero
  end
end
