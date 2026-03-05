# frozen_string_literal: true

require "rails_helper"

describe Cluster, :without_tenant do
  # Maps every ApplicationRecord subclass name to:
  #   :symbol – factory name to call with create() to exercise the destroy cascade
  #   nil     – record is created as a side-effect of another factory; no direct factory needed
  #   false   – excluded: STI abstract base class, non-tenant-scoped model,
  #             or Cluster/Community which the test manages directly
  ALL_MODELS = {
    # ── Billing ──────────────────────────────────────────────────────────────
    "Billing::Account"            => :account,
    "Billing::Statement"          => :statement,
    "Billing::Template"           => :billing_template,
    "Billing::TemplateMemberType" => nil,  # side-effect when member_types added to a template
    "Billing::Transaction"        => :transaction,

    # ── Calendars: Node STI hierarchy ────────────────────────────────────────
    "Calendars::Calendar"                              => :calendar,
    "Calendars::Group"                                 => :calendar_group,
    "Calendars::Node"                                  => false, # STI base; Calendar/Group are the concrete subclasses
    "Calendars::System::BirthdaysCalendar"             => :birthdays_calendar,
    "Calendars::System::CommunityMealsCalendar"        => :community_meals_calendar,
    "Calendars::System::JoinDatesCalendar"             => :join_dates_calendar,
    "Calendars::System::MealsCalendar"                 => false, # STI intermediate base
    "Calendars::System::OtherCommunitiesMealsCalendar" => :other_communities_meals_calendar,
    "Calendars::System::UserAnniversariesCalendar"     => false, # STI intermediate base
    "Calendars::System::YourJobsCalendar"              => :your_jobs_calendar,
    "Calendars::System::YourMealsCalendar"             => :your_meals_calendar,
    "Calendars::SystemCalendar"                        => false, # STI intermediate base

    # ── Calendars: Events, Protocols, Guidelines ─────────────────────────────
    "Calendars::Event"              => :event,
    "Calendars::Eventlet"           => :eventlet,
    "Calendars::GuidelineInclusion" => nil,  # side-effect of :calendar :with_shared_guidelines
    "Calendars::Protocol"           => :calendar_protocol,
    "Calendars::Protocoling"        => nil,  # side-effect: created when a protocol is applied to a calendar
    "Calendars::SharedGuidelines"   => nil,  # side-effect of :calendar :with_shared_guidelines

    # ── Top-level ─────────────────────────────────────────────────────────────
    "Cluster"         => false, # the cluster under test; not a tenant record
    "Community"       => false, # created lazily via Defaults.community; managed directly
    "Domain"          => :domain,
    "DomainOwnership" => nil,   # side-effect of :domain factory

    # ── Feature flags (not cluster-scoped) ────────────────────────────────────
    "FeatureFlag"     => false,
    "FeatureFlagUser" => false,

    # ── GDrive ────────────────────────────────────────────────────────────────
    "GDrive::Config"               => :gdrive_config,
    "GDrive::Item"                 => :gdrive_item,
    "GDrive::ItemGroup"            => :gdrive_item_group,
    "GDrive::Migration::File"      => :gdrive_migration_file,
    "GDrive::Migration::FolderMap" => :gdrive_migration_folder_map,
    "GDrive::Migration::Log"       => :gdrive_migration_log,
    "GDrive::Migration::Operation" => :gdrive_migration_operation,
    "GDrive::Migration::Request"   => :gdrive_migration_request,
    "GDrive::Migration::Scan"      => :gdrive_migration_scan,
    "GDrive::Migration::ScanTask"  => :gdrive_migration_scan_task,
    "GDrive::SyncedPermission"     => :gdrive_synced_permission,
    "GDrive::Token"                => :gdrive_token,

    # ── Groups ────────────────────────────────────────────────────────────────
    "Groups::Affiliation"   => nil, # side-effect: created when a group gains community affiliations
    "Groups::Group"         => :group,
    "Groups::Mailman::List" => :group_mailman_list,
    "Groups::Mailman::User" => :group_mailman_user,
    "Groups::Membership"    => :group_membership,

    # ── Household & User ──────────────────────────────────────────────────────
    "Household" => :household,
    "User"      => :user,

    # ── MailTestRun (not cluster-scoped) ──────────────────────────────────────
    "MailTestRun" => false,

    # ── Meals ─────────────────────────────────────────────────────────────────
    "Meals::Assignment"           => nil,  # side-effect of :meal factory (assignments are created inline)
    "Meals::Cost"                 => :meal_cost,
    "Meals::CostPart"             => nil,  # side-effect of :meal_cost :with_parts
    "Meals::Formula"              => :meal_formula,
    "Meals::FormulaPart"          => nil,  # side-effect of :meal_formula factory
    "Meals::FormulaRole"          => nil,  # side-effect of :meal_formula factory
    "Meals::Import"               => :meal_import,
    "Meals::Invitation"           => nil,  # side-effect of :meal factory (community invitations)
    "Meals::Meal"                 => :meal,
    "Meals::Message"              => :meal_message,
    "Meals::Resourcing"           => nil,  # side-effect of :meal factory (calendar associations)
    "Meals::Restriction"          => :restriction,
    "Meals::Role"                 => :meal_role,
    "Meals::RoleReminder"         => :meal_role_reminder,
    "Meals::RoleReminderDelivery" => nil,  # created by background jobs
    "Meals::Signup"               => :meal_signup,
    "Meals::SignupPart"           => nil,  # side-effect of :meal_signup factory
    "Meals::Type"                 => :meal_type,

    # ── People ────────────────────────────────────────────────────────────────
    "People::EmergencyContact" => :emergency_contact,
    "People::Guardianship"     => nil,  # side-effect: household child/guardian relationship
    "People::MemberType"       => :member_type,
    "People::Memorial"         => :memorial,
    "People::MemorialMessage"  => :memorial_message,
    "People::Pet"              => :pet,
    "People::Vehicle"          => :vehicle,

    # ── Reminder STI hierarchy ────────────────────────────────────────────────
    "Reminder"         => false,  # STI abstract base; covered by Work::JobReminder and Meals::RoleReminder
    "ReminderDelivery" => false,  # STI abstract base; covered by job/role delivery subclasses

    # ── Role (Rolify; not cluster-scoped) ─────────────────────────────────────
    "Role" => false,

    # ── Subscription ──────────────────────────────────────────────────────────
    "Subscription::Intent"       => :subscription_intent,
    "Subscription::Subscription" => :subscription,

    # ── Wiki ──────────────────────────────────────────────────────────────────
    "Wiki::Page"        => :wiki_page,
    "Wiki::PageVersion" => nil,  # side-effect of wiki page creation

    # ── Work ──────────────────────────────────────────────────────────────────
    "Work::Assignment"          => :work_assignment,
    "Work::Job"                 => :work_job,
    "Work::JobReminder"         => :work_job_reminder,
    "Work::JobReminderDelivery" => nil,  # created by background jobs
    "Work::MealJobSyncSetting"  => :work_meal_job_sync_setting,
    "Work::Period"              => :work_period,
    "Work::Share"               => :work_share,
    "Work::Shift"               => :work_shift
  }.freeze

  it "ALL_MODELS covers all ApplicationRecord descendants" do
    Rails.application.eager_load!
    actual = ApplicationRecord.descendants.reject(&:test_mock?).map(&:name).sort
    missing = actual - ALL_MODELS.keys
    extra = ALL_MODELS.keys - actual
    expect(missing).to be_empty, "Add these to ALL_MODELS in cluster_spec.rb: #{missing.join(', ')}"
    expect(extra).to be_empty,
      "Remove these from ALL_MODELS in cluster_spec.rb (class no longer exists): #{extra.join(', ')}"
  end

  it "destroys cleanly" do
    cluster = create(:cluster)

    ActsAsTenant.with_tenant(cluster) do
      # GDrive::Migration sub-records all associate to an operation, and operations have a unique
      # constraint on community_id. Create one shared operation and use it for all migration records.
      migration_models = %w[GDrive::Migration::File GDrive::Migration::FolderMap
                            GDrive::Migration::Log GDrive::Migration::Request
                            GDrive::Migration::Scan GDrive::Migration::ScanTask]

      # Create one instance of each model that has a factory. Defaults.community is created lazily
      # inside the tenant context so all records end up owned by this cluster.
      # Ensure a household exists before creating models that require one as a non-null column.
      shared_household = create(:household)

      # Create a shared GDrive::Config upfront. GDrive::Item, GDrive::Token, and
      # GDrive::SyncedPermission factories each create their own GDrive::Config via association,
      # which would leave multiple configs referencing the same community — but Community has_one
      # :gdrive_config (dependent: :destroy) which only deletes one of them, causing a FK violation
      # on destroy. Reuse a single config and item to avoid this.
      shared_gdrive_config = create(:gdrive_config)
      shared_gdrive_item = create(:gdrive_item, gdrive_config: shared_gdrive_config)

      # Some factories require extra options to satisfy validations or non-null constraints.
      factory_overrides = {
        meal_signup: {diner_counts: [1]},
        pet: {household: shared_household},
        vehicle: {household: shared_household},
        emergency_contact: {household: shared_household},
        gdrive_item: {gdrive_config: shared_gdrive_config},
        gdrive_item_group: {item: shared_gdrive_item},
        gdrive_token: {gdrive_config: shared_gdrive_config},
        gdrive_synced_permission: {item: shared_gdrive_item}
      }

      ALL_MODELS.each do |name, factory|
        next unless factory.is_a?(Symbol)
        next if migration_models.include?(name)
        next if name == "GDrive::Config" # already created as shared_gdrive_config; Community has_one
        create(factory, **factory_overrides.fetch(factory, {}))
      end

      # Create migration sub-records sharing one operation to avoid the unique-per-community constraint.
      operation = GDrive::Migration::Operation.first
      scan = create(:gdrive_migration_scan, operation: operation)
      create(:gdrive_migration_scan_task, scan: scan)
      create(:gdrive_migration_file, operation: operation)
      create(:gdrive_migration_folder_map, operation: operation)
      create(:gdrive_migration_log, operation: operation)
      create(:gdrive_migration_request, operation: operation)

      cluster.destroy!

      Rails.application.eager_load!
      ApplicationRecord.descendants.each do |model|
        next if model.test_mock? || !model.scoped_by_tenant?
        expect(model.count).to eq(0), "Expected to find no #{model.name.pluralize} after cluster.destroy!"
      end
    end
  end
end
