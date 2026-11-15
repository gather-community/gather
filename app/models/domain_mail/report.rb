# frozen_string_literal: true

module DomainMail
  # Assembles the data for the admin domains dashboard: one Status per domain, read from the
  # stored Checks. Fetching happens in RefreshJob or Admin::DomainsController#refresh, not here.
  class Report
    attr_reader :statuses

    def initialize(domains:)
      @statuses = domains.map { |domain| Status.new(domain: domain) }
    end

    def all_correct_count
      statuses.count(&:all_correct?)
    end

    def any_checked?
      statuses.any?(&:checked?)
    end
  end
end
