# frozen_string_literal: true

module MailMigration
  # Builds the data for the mail domain migration page: one DomainStatus per domain, plus an
  # account-level error state when SMTP2GO can't be queried (statuses then degrade to :unknown
  # and the page still renders with DNS status only).
  class Report
    attr_reader :statuses, :smtp2go_error

    def initialize(domains:, client: Smtp2go::Client.new, dns_checker: DnsChecker.new)
      @domains = domains
      @client = client
      @dns_checker = dns_checker
    end

    def generate
      smtp2go_domains = fetch_smtp2go_domains
      @statuses = @domains.map do |domain|
        DomainStatus.new(domain: domain, smtp2go_domain: smtp2go_domains&.[](domain.name.downcase),
          smtp2go_available: !smtp2go_domains.nil?, dns_checker: @dns_checker)
      end
      self
    end

    def migrated_count
      statuses.count(&:migrated?)
    end

    private

    # Returns SenderDomains keyed by downcased name, or nil when the API can't be queried (no key
    # configured, or the request failed). A failed request is reported to Sentry since it may mean
    # a revoked key or an API change; the not-configured case is expected in dev.
    def fetch_smtp2go_domains
      unless @client.configured?
        @smtp2go_error = :not_configured
        return nil
      end
      @client.sender_domains.index_by { |domain| domain.name.downcase }
    rescue Smtp2go::Client::RequestError => e
      Gather::ErrorReporter.instance.report(e, data: {context: "mail_migration_report"})
      @smtp2go_error = :request_failed
      nil
    end
  end
end
