# frozen_string_literal: true

require "rails_helper"

describe Community, :without_tenant do
  # Models excluded from data-setup verification and post-destroy count checks:
  #   - STI abstract bases (only concrete leaf subclasses are instantiated)
  #   - Not tenant-scoped (outside the cluster/community lifecycle)
  #   - Cluster and Community, managed directly by this test
  #   - Side-effect models (created automatically by another factory)
  #   - Cluster-scoped but not community-scoped (survive community deletion)
  #   - Groups::Group, tested explicitly via group_only / group_spanning below
  EXEMPT_MODELS = %w[
    Billing::TemplateMemberType
    Calendars::GuidelineInclusion
    Calendars::Node
    Calendars::Protocoling
    Calendars::SharedGuidelines
    Calendars::System::MealsCalendar
    Calendars::System::UserAnniversariesCalendar
    Calendars::SystemCalendar
    Cluster
    Communities::Signup
    Community
    Domain
    DomainOwnership
    FeatureFlag
    FeatureFlagUser
    Groups::Affiliation
    Groups::Group
    MailTestRun
    Meals::Assignment
    Meals::CostPart
    Meals::FormulaPart
    Meals::FormulaRole
    Meals::Invitation
    Meals::Resourcing
    Meals::RoleReminderDelivery
    Meals::SignupPart
    People::Guardianship
    Reminder
    ReminderDelivery
    Role
    Wiki::PageVersion
    Work::JobReminderDelivery
  ].freeze

  it "EXEMPT_MODELS has no stale entries" do
    Rails.application.eager_load!
    actual = ApplicationRecord.descendants.reject(&:test_mock?).map(&:name)
    stale = EXEMPT_MODELS - actual
    expect(stale).to be_empty,
      "Remove these from EXEMPT_MODELS in community_deletion_spec.rb (class no longer exists): #{stale.join(', ')}"
  end

  it "destroys all associated records without FK violations, and handles group orphaning" do
    cluster = create(:cluster)

    ActsAsTenant.with_tenant(cluster) do
      # community2 exists to verify that spanning groups survive when only one of their
      # communities is destroyed. All factory records are created under Defaults.community (community1).
      community2 = create(:community)

      # ── Shared fixtures needed by multiple factories ───────────────────────
      shared_household = create(:household)
      # A single GDrive::Config for community1. Item/Token/SyncedPermission factories would each
      # create their own config, but Community has_one :gdrive_config so only one can be destroyed
      # cleanly. All gdrive factories share this one config and item.
      shared_gdrive_config = create(:gdrive_config)
      shared_gdrive_item   = create(:gdrive_item, gdrive_config: shared_gdrive_config)

      # ── Billing ───────────────────────────────────────────────────────────
      create(:account)
      create(:statement)
      create(:billing_template)
      create(:transaction)

      # ── Calendars ─────────────────────────────────────────────────────────
      create(:calendar)
      create(:calendar_group)
      create(:birthdays_calendar)
      create(:community_meals_calendar)
      create(:join_dates_calendar)
      create(:other_communities_meals_calendar)
      create(:your_jobs_calendar)
      create(:your_meals_calendar)
      create(:event)
      create(:eventlet)
      create(:calendar_protocol)

      # ── Domain ────────────────────────────────────────────────────────────
      create(:domain)

      # ── GDrive ────────────────────────────────────────────────────────────
      # shared_gdrive_config already created above
      create(:gdrive_item,              gdrive_config: shared_gdrive_config)
      create(:gdrive_item_group,        item: shared_gdrive_item)
      create(:gdrive_token,             gdrive_config: shared_gdrive_config)
      create(:gdrive_synced_permission, item: shared_gdrive_item)

      # Migration sub-records share one operation (unique-per-community constraint).
      operation = create(:gdrive_migration_operation)
      scan      = create(:gdrive_migration_scan, operation: operation)
      create(:gdrive_migration_scan_task, scan: scan)
      create(:gdrive_migration_file,       operation: operation)
      create(:gdrive_migration_folder_map, operation: operation)
      create(:gdrive_migration_log,        operation: operation)
      create(:gdrive_migration_request,    operation: operation)

      # ── Groups ────────────────────────────────────────────────────────────
      create(:group)
      create(:group_mailman_list)
      create(:group_mailman_user)
      create(:group_membership)

      # ── People ────────────────────────────────────────────────────────────
      create(:user)
      create(:emergency_contact, household: shared_household)
      create(:member_type, community: Defaults.community)
      create(:memorial)
      create(:memorial_message)
      create(:pet,     household: shared_household)
      create(:vehicle, household: shared_household)

      # ── Meals ─────────────────────────────────────────────────────────────
      create(:meal_cost)
      create(:meal_formula)
      create(:meal_import)
      create(:meal)
      create(:meal_message)
      create(:restriction)
      create(:meal_role)
      create(:meal_role_reminder)
      create(:meal_signup, diner_counts: [1])
      create(:meal_type)

      # ── Subscription ──────────────────────────────────────────────────────
      create(:subscription_intent, community: Defaults.community)
      create(:subscription, community: Defaults.community)

      # ── Wiki ──────────────────────────────────────────────────────────────
      create(:wiki_page)

      # ── Work ──────────────────────────────────────────────────────────────
      create(:work_assignment)
      create(:work_job)
      create(:work_job_reminder)
      create(:work_meal_job_sync_setting)
      create(:work_period)
      create(:work_share)
      create(:work_shift)

      # ── Groups for the orphan test ────────────────────────────────────────
      group_only     = create(:group)
      group_spanning = create(:group)
      group_spanning.communities << community2

      # Pre-destroy: every non-exempt, tenant-scoped model should have at least one record.
      # This catches any newly added model that needs an explicit factory call above.
      Rails.application.eager_load!
      ApplicationRecord.descendants.each do |model|
        next if model.test_mock? || !model.scoped_by_tenant? || model.name.in?(EXEMPT_MODELS)
        expect(model.count).to be > 0,
          "Setup incomplete: expected at least one #{model.name} before community destroy. " \
          "Add a factory call above or add it to EXEMPT_MODELS."
      end

      Defaults.community.destroy!

      # Post-destroy: every non-exempt, tenant-scoped model's records should be gone.
      ApplicationRecord.descendants.each do |model|
        next if model.test_mock? || !model.scoped_by_tenant? || model.name.in?(EXEMPT_MODELS)
        expect(model.count).to eq(0),
          "Expected no #{model.name} records to remain after community destroy"
      end

      # A group affiliated only with the destroyed community must be gone; one that also
      # belongs to community2 must survive.
      expect(Groups::Group.exists?(group_only.id)).to be(false),
        "group affiliated only with the destroyed community should be gone"
      expect(Groups::Group.exists?(group_spanning.id)).to be(true),
        "group spanning two communities should survive when only one is destroyed"
    end
  end
end
