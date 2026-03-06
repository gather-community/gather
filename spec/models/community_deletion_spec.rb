# frozen_string_literal: true

require "rails_helper"

describe Community, :without_tenant do
  # Models excluded from data-setup verification and post-destroy count checks.
  EXEMPT_MODELS = [
    "Calendars::Node",                              # STI abstract base; Calendar/Group are the leaf classes
    "Calendars::System::MealsCalendar",             # STI intermediate base
    "Calendars::System::UserAnniversariesCalendar", # STI intermediate base
    "Calendars::SystemCalendar",                    # STI intermediate base
    "Cluster",                                      # managed directly by this test; not community-scoped
    "Communities::Signup",                          # not tenant-scoped; outside the cluster/community lifecycle
    "Community",                                    # managed directly by this test (Defaults.community is destroyed)
    "Domain",                                       # cluster-scoped, spans communities; orphan cleanup tested below
    "DomainOwnership",                              # destroyed via community cascade; Domain survival tested below
    "FeatureFlag",                                  # not tenant-scoped
    "FeatureFlagUser",                              # not tenant-scoped
    "Groups::Affiliation",                          # destroyed via community cascade; Group survival tested below
    "Groups::Group",                                # cluster-scoped, spans communities; orphan cleanup tested below
    "MailTestRun",                                  # not tenant-scoped
    "Reminder",                                     # STI abstract base; JobReminder/RoleReminder are the leaves
    "ReminderDelivery",                             # STI abstract base; job/role delivery subclasses are the leaves
    "Role",                                         # Rolify; not tenant-scoped
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
      billing_template = create(:billing_template)
      create(:transaction)

      # ── Calendars ─────────────────────────────────────────────────────────
      create(:calendar, :with_shared_guidelines)
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
      create(:calendar_protocoling)

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
      create(:user, :child) # also creates People::Guardianship
      create(:emergency_contact, household: shared_household)
      member_type = create(:member_type, community: Defaults.community)
      billing_template.member_types << member_type # also creates Billing::TemplateMemberType
      create(:memorial)
      create(:memorial_message)
      create(:pet,     household: shared_household)
      create(:vehicle, household: shared_household)

      # ── Meals ─────────────────────────────────────────────────────────────
      create(:meal_cost, :with_parts)
      create(:meal_formula)
      create(:meal_import)
      create(:meal)
      create(:meal_message)
      create(:restriction)
      create(:meal_role)
      create(:meal_role_reminder)
      create(:meal_role_reminder_delivery)
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
      create(:work_job_reminder_delivery)
      create(:work_meal_job_sync_setting)
      create(:work_period)
      create(:work_share)
      create(:work_shift)

      # ── Orphan tests: domain and group ────────────────────────────────────
      domain_only     = create(:domain)
      domain_spanning = create(:domain)
      domain_spanning.communities << community2

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

      # A domain/group affiliated only with the destroyed community must be gone;
      # one that also belongs to community2 must survive.
      expect(Domain.exists?(domain_only.id)).to be(false),
        "domain affiliated only with the destroyed community should be gone"
      expect(Domain.exists?(domain_spanning.id)).to be(true),
        "domain spanning two communities should survive when only one is destroyed"
      expect(Groups::Group.exists?(group_only.id)).to be(false),
        "group affiliated only with the destroyed community should be gone"
      expect(Groups::Group.exists?(group_spanning.id)).to be(true),
        "group spanning two communities should survive when only one is destroyed"
    end
  end
end
