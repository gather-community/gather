# frozen_string_literal: true

require "rails_helper"

describe "database" do
  it "has cluster_id on all tables except select few" do
    connection = ActiveRecord::Base.connection
    no_cluster = connection.tables.select { |t| connection.columns(t).none? { |c| c.name == "cluster_id" } }
    expect(no_cluster).to match_array(
      %w[active_storage_attachments active_storage_blobs ar_internal_metadata clusters
         delayed_jobs meal_formula_roles old_credit_balances
         roles schema_migrations users_roles]
    )
  end
end
