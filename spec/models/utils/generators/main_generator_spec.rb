# frozen_string_literal: true

require "rails_helper"
require "fileutils"

# Don't delay jobs so that any mails would get sent immediately
describe Utils::Generators::MainGenerator, :without_tenant, :perform_jobs do
  # Classes that are allowed to have no sample data
  NO_SAMPLE_DATA_CLASSES = %w[
    Billing::Template
    Billing::TemplateMemberType
    Calendars::System::OtherCommunitiesMealsCalendar
    Domain
    DomainOwnership
    FeatureFlag
    FeatureFlagUser
    GDrive::Config
    GDrive::MainConfig
    GDrive::MigrationConfig
    GDrive::Item
    GDrive::ItemGroup
    GDrive::SyncedPermission
    GDrive::Token
    GDrive::Migration::Request
    GDrive::Migration::File
    GDrive::Migration::FolderMap
    GDrive::Migration::Log
    GDrive::Migration::Operation
    GDrive::Migration::Scan
    GDrive::Migration::ScanTask
    Groups::Mailman::List
    Groups::Mailman::User
    MailTestRun
    Meals::Import
    Meals::Message
    People::MemberType
    Subscription::Subscription
    Subscription::Intent
    Wiki::Page
    Wiki::PageVersion
    Work::JobReminderDelivery
    Work::MealJobSyncSetting
  ].freeze

  before do
    FileUtils.rm_rf(Rails.root.join("public", "system", "test"))
  end

  it "should run and destroy cleanly with sample data and no photos (runs faster)" do
    cluster = nil

    expect do
      main = described_class.new(cmty_name: "Foo Community", slug: "foo", sample_data: true, photos: false)
      cluster = main.generate
    end.to change { ActionMailer::Base.deliveries.size }.by(0)

    ActsAsTenant.with_tenant(cluster) do
      check_cmty_and_cluster_creation(cluster)
      expect_no_admins

      # Ensure data is getting generated for all classes except those with explicit exceptions.
      Rails.application.eager_load!
      dataless = []
      ApplicationRecord.descendants.each do |model|
        next if model.test_mock? || NO_SAMPLE_DATA_CLASSES.include?(model.name)
        dataless << model.name if model.none?
      end
      expect(dataless).to be_empty, "#{dataless.join(", ")} don't have any sample data"

      # Destroy and check
      Utils::SampleDataRemover.new(cluster).remove
      cluster.communities[0].destroy
      ApplicationRecord.descendants.each do |model|
        next if model.test_mock? || !model.scoped_by_tenant?
        expect(model.count).to eq(0), "Expected to find no #{model.name.pluralize}"
      end
    end
  end

  it "should generate and destroy photos" do
    cluster = nil
    main = described_class.new(cmty_name: "Foo Community", slug: "foo", sample_data: true, photos: true)
    cluster = main.generate

    ActsAsTenant.with_tenant(cluster) do
      # Ensure photos are generated.
      expect(ActiveStorage::Blob.count).to be > 12

      # Destroy and check
      Utils::SampleDataRemover.new(cluster).remove
      cluster.communities[0].destroy
      expect(ActiveStorage::Blob.count).to eq(0)
    end
  end

  it "should run cleanly without sample data" do
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
      expect(Calendars::Event.count).to eq(0)
      expect(Calendars::Calendar.count).to eq(7)
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
