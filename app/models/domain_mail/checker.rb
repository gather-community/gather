# frozen_string_literal: true

module DomainMail
  # Runs the mail checks (DNS lookups plus one SMTP2GO API call) for the given domains and
  # stores the results as Check rows. Exposes smtp2go_error (:not_configured / :request_failed)
  # when the SMTP2GO API couldn't be queried; DNS results are still stored in that case.
  class Checker
    attr_reader :smtp2go_error

    def initialize(domains:, client: Smtp2go::Client.new, dns_checker: DnsChecker.new)
      @domains = domains
      @client = client
      @dns_checker = dns_checker
    end

    def run
      smtp2go_domains = fetch_smtp2go_domains
      @domains.each do |domain|
        data = check_data(domain, smtp2go_domains)
        ActsAsTenant.with_tenant(domain.cluster) do
          check = Check.find_or_initialize_by(domain: domain)
          check.update!(data: data, checked_at: Time.current)
        end
      end
    end

    private

    def check_data(domain, smtp2go_domains)
      smtp2go_domain = smtp2go_domains&.[](domain.name.downcase)
      {
        "mx" => @dns_checker.mx_records(domain.name),
        "spf" => @dns_checker.spf_record(domain.name),
        "smtp2go_status" => smtp2go_status(smtp2go_domain, available: !smtp2go_domains.nil?),
        "validation_records" => validation_records(smtp2go_domain)
      }
    end

    def smtp2go_status(smtp2go_domain, available:)
      if !available
        "unknown"
      elsif smtp2go_domain.nil?
        "not_added"
      elsif smtp2go_domain.verified?
        "verified"
      else
        "pending"
      end
    end

    # The in_dns flag is our own CNAME lookup, independent of SMTP2GO's verified flag, because
    # our lookup can run ahead of SMTP2GO's periodic verification (roughly every seven minutes).
    def validation_records(smtp2go_domain)
      return [] if smtp2go_domain.nil?
      smtp2go_domain.records.map do |record|
        actual = @dns_checker.cname_target(record.host)
        {
          "kind" => record.kind.to_s,
          "host" => record.host,
          "target" => record.target,
          "actual" => actual,
          "verified" => record.verified,
          "in_dns" => actual == record.target&.downcase
        }
      end
    end

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
      Gather::ErrorReporter.instance.report(e, data: {context: "domain_mail_checker"})
      @smtp2go_error = :request_failed
      nil
    end
  end
end
