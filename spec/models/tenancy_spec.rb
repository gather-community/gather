# frozen_string_literal: true

require "rails_helper"

describe "tenancy" do
  ALLOWLISTED_TABLES = %w[active_storage_attachments active_storage_blobs active_storage_variant_records
    ar_internal_metadata clusters community_signups delayed_jobs feature_flags feature_flag_users
    roles schema_migrations users_roles mail_test_runs meal_restrictions_signup_parts
    stripe_webhook_events subscription_exchange_rates subscription_inflation_readings].freeze
  ALLOWLISTED_CLASSES = %w[Communities::Signup Role Cluster FeatureFlag FeatureFlagUser MailTestRun
    Stripe::WebhookEvent Subscription::ExchangeRate Subscription::InflationReading].freeze

  it "all tables except allowlisted ones have cluster_id" do
    ApplicationRecord.connection.tables.each do |table|
      next if ALLOWLISTED_TABLES.include?(table)
      expect(ApplicationRecord.connection.column_exists?(table, :cluster_id))
        .to be(true), "#{table} doesn't have cluster_id"
    end
  end

  it "all models except allowlisted ones have acts_as_tenant" do
    Rails.application.eager_load!
    models = ApplicationRecord.descendants
    expect(models.size).to be > 20 # Make sure models are eager loaded.
    models.each do |model|
      next if model.test_mock? || ALLOWLISTED_CLASSES.include?(model.name)
      expect(model).to be_scoped_by_tenant, "#{model.name} doesn't have acts_as_tenant"
    end
  end
end
