# frozen_string_literal: true

# Operator page tracking the migration of custom mail domains to the new SMTP host. Statuses are
# stored (written by MailMigration::RefreshJob) and refreshed on demand, not fetched per request.
class MailMigrationController < ApplicationController
  # Rough seconds per domain for the refresh flash estimate: a few DNS lookups each, plus
  # fixed overhead for job pickup and the single SMTP2GO API call.
  REFRESH_OVERHEAD_SECONDS = 5
  REFRESH_SECONDS_PER_DOMAIN = 1

  def index
    authorize(:mail_migration)
    domains = policy_scope(Domain).custom.by_name.includes(:communities, :mail_migration_check)
    @report = MailMigration::Report.new(domains: domains)
    @smtp2go_configured = Smtp2go::Client.new.configured?
  end

  def refresh
    authorize(:mail_migration)
    domain = params[:domain_id].present? ? policy_scope(Domain).custom.find(params[:domain_id]) : nil
    MailMigration::RefreshJob.perform_later(domain_id: domain&.id)
    count = domain ? 1 : policy_scope(Domain).custom.count
    seconds = REFRESH_OVERHEAD_SECONDS + REFRESH_SECONDS_PER_DOMAIN * count
    flash[:success] = t("mail_migration.refresh_started", count: count, seconds: seconds)
    redirect_to(mail_migration_path)
  end

  protected

  def apex_domain_only
    true
  end
end
