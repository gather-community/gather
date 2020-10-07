# frozen_string_literal: true

require "rails_helper"

describe "tenancy" do
  WHITELISTED_TABLES = %w[active_storage_attachments active_storage_blobs ar_internal_metadata
                          clusters delayed_jobs roles schema_migrations users_roles].freeze
  WHITELISTED_CLASSES = %w[Role Cluster].freeze

  it "all tables except whitelisted ones have cluster_id" do
    ApplicationRecord.connection.tables.each do |table|
      next if WHITELISTED_TABLES.include?(table)
      expect(ApplicationRecord.connection.column_exists?(table, :cluster_id))
        .to be(true), "#{table} doesn't have cluster_id"
    end
  end

  it "all models except whitelisted ones have acts_as_tenant" do
    Rails.application.eager_load!
    models = ApplicationRecord.descendants
    expect(models.size).to be > 20 # Make sure models are eager loaded.
    models.each do |model|
      next unless model.table_exists? # Don't check non-persisted classes
      next if WHITELISTED_CLASSES.include?(model.name)
      expect(model).to respond_to(:scoped_by_tenant?), "#{model.name} doesn't have acts_as_tenant"
    end
  end
end
