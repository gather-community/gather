# frozen_string_literal: true

require "rails_helper"

# Wholesome spec: every ActiveRecord model must declare what happens to its rows when a user or a
# household is permanently deleted (People::UserDeletion / People::HouseholdDeletion).
#
# The point is the completeness check at the bottom. A new model that touches User or Household is
# easy to add without considering deletion — the row then either blocks the destroy with a foreign
# key violation or, worse, silently outlives the person it belonged to and keeps their PII. Adding
# a model without a disposition here fails the suite, which forces the question to be answered.
#
# The maps are DECLARATIONS, not assertions — nothing here reads UserDeletion's implementation and
# checks it matches. They must be kept consistent with it by hand. Behaviour is verified in
# user_deletion_spec.rb and household_deletion_spec.rb; this file only guarantees that every model
# has been considered.
#
# Dispositions:
#
#   :none      — unaffected; no relationship to the deleted record.
#   :destroy   — rows are destroyed, via a dependent: :destroy cascade (possibly indirect).
#   :anonymize — rows survive as community history; the reference is repointed at the community's
#                "Deleted Member" placeholder (Community#deleted_member).
#   :nullify   — rows survive; the reference is set to NULL because the attribution is optional.
#   :retain    — rows survive with the reference left pointing at the now-deleted id. Only
#                legitimate where deliberate and documented; see GDrive::SyncedPermission.
#   :subject   — the record being deleted itself.
#
# Where one model needs different treatment per column, the value is a hash of foreign key =>
# disposition rather than a single symbol.
describe "deletion dispositions", :without_tenant do
  # What happens to rows of each model when a User is permanently deleted.
  USER_DISPOSITIONS = {
    "Billing::Account" => :none,
    "Billing::Statement" => :none,
    "Billing::Template" => :none,
    "Billing::TemplateMemberType" => :none,
    "Billing::Transaction" => :none,
    "Calendars::Calendar" => :none,
    # Non-meal events require a creator (DB check constraint), so creator is anonymized rather
    # than nullified. Sponsor is optional attribution.
    "Calendars::Event" => {creator_id: :anonymize, sponsor_id: :nullify},
    "Calendars::EventOverride" => :none,
    "Calendars::Eventlet" => :none,
    "Calendars::EventletOverride" => :none,
    "Calendars::Group" => :none,
    "Calendars::GuidelineInclusion" => :none,
    "Calendars::Node" => :none,
    "Calendars::Protocol" => :none,
    "Calendars::Protocoling" => :none,
    "Calendars::SharedGuidelines" => :none,
    "Calendars::System::BirthdaysCalendar" => :none,
    "Calendars::System::CommunityMealsCalendar" => :none,
    "Calendars::System::JoinDatesCalendar" => :none,
    "Calendars::System::MealsCalendar" => :none,
    "Calendars::System::OtherCommunitiesMealsCalendar" => :none,
    "Calendars::System::UserAnniversariesCalendar" => :none,
    "Calendars::System::YourJobsCalendar" => :none,
    "Calendars::System::YourMealsCalendar" => :none,
    "Calendars::SystemCalendar" => :none,
    "Cluster" => :none,
    # Apex-level (not tenant-scoped) back-reference; nullified so the destroy isn't FK-blocked.
    "Communities::Signup" => {reviewed_by_id: :nullify},
    "Community" => :none,
    "Domain" => :none,
    "DomainOwnership" => :none,
    "FeatureFlag" => :none,
    "FeatureFlagUser" => :destroy,
    "GDrive::Config" => :none,
    "GDrive::Item" => :none,
    "GDrive::ItemGroup" => :none,
    "GDrive::Migration::File" => :none,
    "GDrive::Migration::FolderMap" => :none,
    "GDrive::Migration::Log" => :none,
    "GDrive::Migration::Operation" => :none,
    "GDrive::Migration::Request" => :none,
    "GDrive::Migration::Scan" => :none,
    "GDrive::Migration::ScanTask" => :none,
    # Deliberately dependent: nil (see User#gdrive_synced_permissions) — PermissionSyncJob searches
    # by user id to revoke the Google-side permission, so the row must outlive the user.
    "GDrive::SyncedPermission" => :retain,
    "GDrive::Token" => :none,
    "Groups::Affiliation" => :none,
    "Groups::Group" => :none,
    "Groups::Mailman::List" => :none,
    "Groups::Mailman::User" => :destroy,
    "Groups::Membership" => :destroy,
    "Household" => :none,
    "MailTestRun" => :none,
    "Meals::Assignment" => :destroy,
    "Meals::Cost" => {reimbursee_id: :nullify},
    "Meals::CostPart" => :none,
    "Meals::Formula" => :none,
    "Meals::FormulaPart" => :none,
    "Meals::FormulaRole" => :none,
    "Meals::Import" => :anonymize,
    "Meals::Invitation" => :none,
    "Meals::Meal" => :anonymize,
    # Community history sent to the team/diners; sender_id is NOT NULL so it must be repointed.
    "Meals::Message" => :anonymize,
    "Meals::Resourcing" => :none,
    "Meals::Restriction" => :none,
    "Meals::Role" => :none,
    "Meals::RoleReminder" => :none,
    "Meals::RoleReminderDelivery" => :none,
    "Meals::Signup" => :none,
    "Meals::SignupPart" => :none,
    "Meals::Type" => :none,
    "Messaging::Account" => :none,
    "Messaging::Transaction" => {creator_id: :nullify},
    "People::EmergencyContact" => :none,
    "People::Guardianship" => :destroy,
    "People::MemberType" => :none,
    "People::Memorial" => :destroy,
    "People::MemorialMessage" => :destroy,
    "People::Pet" => :none,
    "People::Vehicle" => :none,
    "Reminder" => :none,
    "ReminderDelivery" => :none,
    # users_roles join rows go with the user; Role itself is shared and unaffected.
    "Role" => :none,
    "Stripe::WebhookEvent" => :none,
    "Subscription::ExchangeRate" => :none,
    "Subscription::InflationReading" => :none,
    "Subscription::Intent" => :none,
    "Subscription::MessagingTopup" => :none,
    "Subscription::Subscription" => :none,
    "User" => {id: :subject, job_choosing_proxy_id: :nullify},
    "Wiki::Page" => {creator_id: :anonymize, updater_id: :anonymize},
    "Wiki::PageVersion" => {updater_id: :anonymize},
    "Work::Assignment" => :destroy,
    "Work::Job" => :none,
    "Work::JobReminder" => :none,
    "Work::JobReminderDelivery" => :none,
    "Work::MealJobSyncSetting" => :none,
    "Work::Period" => :none,
    "Work::Share" => :destroy,
    "Work::Shift" => :none
  }.freeze

  # What happens to rows of each model when a Household is permanently deleted. HouseholdDeletion
  # runs UserDeletion#reassign_only for each member first, so everything anonymized above is
  # anonymized here too; the household's own dependents then cascade.
  #
  # There are deliberately no :anonymize entries today — nothing is authored by a household, only
  # by its members. The value is left in the vocabulary for when that changes.
  HOUSEHOLD_DISPOSITIONS = USER_DISPOSITIONS.merge(
    # Cascade from Household#accounts, and from Account's own dependents.
    "Billing::Account" => :destroy,
    "Billing::Statement" => :destroy,
    "Billing::Transaction" => :destroy,
    "Meals::Signup" => :destroy,
    "People::EmergencyContact" => :destroy,
    "People::Pet" => :destroy,
    "People::Vehicle" => :destroy,
    "Household" => :subject,
    # Every member is deleted along with the household.
    "User" => :destroy
  ).freeze

  VALID_DISPOSITIONS = %i[none destroy anonymize nullify retain subject].freeze

  def all_model_names
    Rails.application.eager_load!
    ApplicationRecord.descendants.reject(&:test_mock?).map(&:name)
  end

  {"USER_DISPOSITIONS" => USER_DISPOSITIONS,
   "HOUSEHOLD_DISPOSITIONS" => HOUSEHOLD_DISPOSITIONS}.each do |const_name, map|
    describe const_name do
      it "covers every model" do
        models = all_model_names
        # Guard against a partial eager load silently making this pass.
        expect(models.size).to be > 20

        missing = models - map.keys
        expect(missing).to be_empty, "Add these models to #{const_name} in " \
          "deletion_dispositions_spec.rb, declaring what happens to their rows when a " \
          "#{const_name.split("_").first.downcase} is permanently deleted. If they reference the " \
          "deleted record, People::UserDeletion/HouseholdDeletion probably needs updating too: " \
          "#{missing.sort.join(", ")}"
      end

      it "has no stale entries" do
        stale = map.keys - all_model_names
        expect(stale).to be_empty,
          "Remove these from #{const_name} in deletion_dispositions_spec.rb " \
          "(class no longer exists): #{stale.sort.join(", ")}"
      end

      it "uses only recognized dispositions" do
        bad = map.filter_map do |model, disposition|
          values = disposition.is_a?(Hash) ? disposition.values : [disposition]
          invalid = values - VALID_DISPOSITIONS
          "#{model} => #{invalid.join(", ")}" if invalid.any?
        end
        expect(bad).to be_empty, "Unrecognized dispositions in #{const_name} " \
          "(expected one of #{VALID_DISPOSITIONS.join(", ")}): #{bad.join("; ")}"
      end

      # Catches the reverse mistake from `missing`: a model added to the map as :none by reflex
      # even though it does reference the deleted record.
      it "declares :none only for models with no association to the deleted record" do
        target = (const_name == "USER_DISPOSITIONS") ? "User" : "Household"
        wrong = map.select { |_model, disposition| disposition == :none }.keys.filter_map do |name|
          refs = belongs_to_names(name.constantize, target)
          "#{name} (#{refs.join(", ")})" if refs.any?
        end
        expect(wrong).to be_empty, "These are declared :none in #{const_name} but do reference " \
          "#{target}. Declare the real disposition and make sure People::#{target}Deletion " \
          "handles them: #{wrong.sort.join("; ")}"
      end
    end
  end

  # Foreign keys on `model` that point at `target`, ignoring associations whose class can't be
  # resolved (polymorphic and the like).
  def belongs_to_names(model, target)
    model.reflect_on_all_associations(:belongs_to).filter_map do |assoc|
      assoc.foreign_key if assoc.klass.name == target
    rescue
      nil
    end
  end
end
