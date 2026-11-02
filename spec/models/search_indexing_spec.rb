# frozen_string_literal: true

require "rails_helper"

# Forces whoever adds a model to decide whether it should appear in global search.
# A model is "indexed" if it (or an STI ancestor) is in SearchController::GATHER_MODELS.
# Models deliberately left out of global search. Keep alphabetized.
NOT_SEARCHABLE_MODELS = [
  "Billing::Account",
  "Billing::Statement",
  "Billing::Template",
  "Billing::TemplateMemberType",
  "Calendars::EventOverride",
  "Calendars::Eventlet",
  "Calendars::EventletOverride",
  "Calendars::Group",
  "Calendars::GuidelineInclusion",
  "Calendars::Node",
  "Calendars::Protocol",
  "Calendars::Protocoling",
  "Calendars::SharedGuidelines",
  "Cluster",
  "Communities::Signup",
  "Community",
  "Domain",
  "DomainMail::Check",
  "DomainOwnership",
  "FeatureFlag",
  "FeatureFlagUser",
  "GDrive::Config",
  "GDrive::Item",
  "GDrive::ItemGroup",
  "GDrive::Migration::File",
  "GDrive::Migration::FolderMap",
  "GDrive::Migration::Log",
  "GDrive::Migration::Operation",
  "GDrive::Migration::Request",
  "GDrive::Migration::Scan",
  "GDrive::Migration::ScanTask",
  "GDrive::SyncedPermission",
  "GDrive::Token",
  "Groups::Affiliation",
  "Groups::Mailman::List",
  "Groups::Mailman::User",
  "Groups::Membership",
  "MailTestRun",
  "Meals::Assignment",
  "Meals::Cost",
  "Meals::CostPart",
  "Meals::Formula",
  "Meals::FormulaPart",
  "Meals::FormulaRole",
  "Meals::Import",
  "Meals::Invitation",
  "Meals::Message",
  "Meals::Resourcing",
  "Meals::Restriction",
  "Meals::Role",
  "Meals::RoleReminder",
  "Meals::RoleReminderDelivery",
  "Meals::Signup",
  "Meals::SignupPart",
  "Meals::Type",
  "Messaging::Account",
  "Messaging::Registration",
  "Messaging::Transaction",
  "People::Guardianship",
  "People::MemberType",
  "People::MemorialMessage",
  "Reminder",
  "ReminderDelivery",
  "Role",
  "Stripe::WebhookEvent",
  "Subscription::ExchangeRate",
  "Subscription::InflationReading",
  "Subscription::Intent",
  "Subscription::MessagingTopup",
  "Subscription::Subscription",
  "Wiki::PageVersion",
  "Work::Assignment",
  "Work::Job",
  "Work::JobReminder",
  "Work::JobReminderDelivery",
  "Work::MealJobSyncSetting",
  "Work::Period",
  "Work::Share",
  "Work::Shift" # Indexed in Elasticsearch for its own shift search page, but not in global search.
].freeze

describe "search indexing" do
  let(:models) do
    Rails.application.eager_load!
    ApplicationRecord.descendants.reject(&:test_mock?)
  end

  def indexed?(model)
    SearchController::GATHER_MODELS.any? { |indexed| model <= indexed }
  end

  it "every model is either in global search or in NOT_SEARCHABLE_MODELS" do
    expect(models.size).to be > 20 # Make sure models are eager loaded.
    undecided = models.reject { |m| indexed?(m) || NOT_SEARCHABLE_MODELS.include?(m.name) }.map(&:name).sort
    expect(undecided).to be_empty,
      "These models are neither in global search nor in NOT_SEARCHABLE_MODELS: #{undecided.join(", ")}. " \
      "Decide whether each should be searchable. If so, index it in Elasticsearch (search config + " \
      "serializer) and add it to SearchController::GATHER_MODELS. If not, add it to " \
      "NOT_SEARCHABLE_MODELS in spec/models/search_indexing_spec.rb."
  end

  it "no model in NOT_SEARCHABLE_MODELS is in global search" do
    contradictions = models.select { |m| indexed?(m) && NOT_SEARCHABLE_MODELS.include?(m.name) }.map(&:name)
    expect(contradictions).to be_empty,
      "These models are in SearchController::GATHER_MODELS (or inherit from a model that is) but are also " \
      "listed in NOT_SEARCHABLE_MODELS: #{contradictions.join(", ")}. " \
      "Remove them from NOT_SEARCHABLE_MODELS in spec/models/search_indexing_spec.rb."
  end

  it "NOT_SEARCHABLE_MODELS has no stale entries" do
    stale = NOT_SEARCHABLE_MODELS - models.map(&:name)
    expect(stale).to be_empty,
      "Remove these from NOT_SEARCHABLE_MODELS in spec/models/search_indexing_spec.rb " \
      "(class no longer exists): #{stale.join(", ")}"
  end

  it "NOT_SEARCHABLE_MODELS is alphabetized" do
    expect(NOT_SEARCHABLE_MODELS).to eq(NOT_SEARCHABLE_MODELS.sort)
  end
end
