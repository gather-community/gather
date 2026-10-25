# frozen_string_literal: true

module MailMigration
  # Assembles the data for the mail domain migration page: one DomainStatus per domain, read from
  # the stored DomainChecks. Fetching happens in RefreshJob, not here.
  class Report
    attr_reader :statuses

    def initialize(domains:)
      @statuses = domains.map { |domain| DomainStatus.new(domain: domain) }
    end

    def migrated_count
      statuses.count(&:migrated?)
    end

    def any_checked?
      statuses.any?(&:checked?)
    end
  end
end
