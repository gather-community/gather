# frozen_string_literal: true

module MailMigration
  # The migration status of one custom domain: whether its MX and SPF records have been updated to
  # the new values, and whether SMTP2GO has validated it as a sender domain — including whether the
  # validation CNAME records are actually present in DNS, which can run ahead of SMTP2GO's periodic
  # verification (it re-checks roughly every seven minutes).
  class DomainStatus
    # What the domain's MX records must be, exactly, for mail to arrive at the new host.
    EXPECTED_MX = [[10, "mail.gather.coop"], [20, "mail2.gather.coop"]].freeze

    # What the domain's SPF record must contain to authorize the new host. The full recommended
    # record is "v=spf1 include:_spf.gather.coop ~all", but a domain may legitimately carry other
    # mechanisms (e.g. for the community's own mail provider), so only the include is required.
    REQUIRED_SPF_INCLUDE = "include:_spf.gather.coop"

    # One SMTP2GO validation record plus whether we can see it in DNS ourselves.
    ValidationRecord = Struct.new(:kind, :host, :target, :verified, :in_dns, keyword_init: true)

    attr_reader :domain, :mx, :spf, :validation_records

    def initialize(domain:, smtp2go_domain:, smtp2go_available:, dns_checker:)
      @domain = domain
      @smtp2go_domain = smtp2go_domain
      @smtp2go_available = smtp2go_available
      @mx = dns_checker.mx_records(domain.name)
      @spf = dns_checker.spf_record(domain.name)
      @validation_records = build_validation_records(dns_checker)
    end

    delegate :communities, to: :domain

    def mx_ok?
      mx == EXPECTED_MX
    end

    def spf_ok?
      spf.present? && spf.include?(REQUIRED_SPF_INCLUDE)
    end

    # :verified / :pending / :not_added, or :unknown when the SMTP2GO API couldn't be queried.
    def smtp2go_status
      if !@smtp2go_available
        :unknown
      elsif @smtp2go_domain.nil?
        :not_added
      elsif @smtp2go_domain.verified?
        :verified
      else
        :pending
      end
    end

    # Which SMTP host the domain's outbound mail goes through. Full SMTP2GO validation is treated
    # as the switchover point: once a domain is verified there, its mail is relayed via SMTP2GO.
    def sending_via
      case smtp2go_status
      when :verified then :smtp2go
      when :unknown then :unknown
      else :legacy
      end
    end

    def migrated?
      mx_ok? && spf_ok? && smtp2go_status == :verified
    end

    private

    def build_validation_records(dns_checker)
      return [] if @smtp2go_domain.nil?
      @smtp2go_domain.records.map do |record|
        ValidationRecord.new(kind: record.kind, host: record.host, target: record.target,
          verified: record.verified,
          in_dns: dns_checker.cname_target(record.host) == record.target&.downcase)
      end
    end
  end
end
