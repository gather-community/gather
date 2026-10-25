# frozen_string_literal: true

# Operator page tracking the migration of custom mail domains to the new SMTP host.
class MailMigrationController < ApplicationController
  def index
    authorize(:mail_migration)
    # Tenant scoping is off on the apex domain, so this covers domains from all clusters.
    domains = policy_scope(Domain).custom.by_name.includes(:communities)
    @report = MailMigration::Report.new(domains: domains).generate
  end

  protected

  def apex_domain_only
    true
  end
end
