# frozen_string_literal: true

module MailMigration
  # Refreshes the stored mail migration checks: one domain when domain_id is given, otherwise
  # every custom domain across all clusters. A full refresh costs one SMTP2GO API call (the
  # domain/view endpoint returns all domains in one response) plus a handful of DNS lookups per
  # domain, so there are no meaningful rate limit concerns.
  class RefreshJob < ApplicationJob
    def perform(domain_id: nil)
      ActsAsTenant.without_tenant do
        domains = domain_id ? Domain.where(id: domain_id).to_a : Domain.custom.includes(:cluster).to_a
        Checker.new(domains: domains).run
      end
    end
  end
end
