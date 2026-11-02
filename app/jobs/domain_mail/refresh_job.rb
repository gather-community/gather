# frozen_string_literal: true

module DomainMail
  # Refreshes the stored mail checks for every custom domain across all clusters. A full refresh
  # costs one SMTP2GO API call (the domain/view endpoint returns all domains in one response)
  # plus a handful of DNS lookups per domain, so there are no meaningful rate limit concerns.
  # Single-domain re-checks run synchronously in Admin::DomainsController instead.
  class RefreshJob < ApplicationJob
    def perform
      ActsAsTenant.without_tenant do
        Checker.new(domains: Domain.custom.includes(:cluster).to_a).run
      end
    end
  end
end
