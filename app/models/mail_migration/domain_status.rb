# frozen_string_literal: true

module MailMigration
  # The migration status of one custom domain, read from its stored DomainCheck (written by
  # RefreshJob): whether its MX and SPF records have been updated to the new values, and whether
  # SMTP2GO has validated it as a sender domain — including whether the validation CNAME records
  # were actually present in DNS at check time. A domain with no stored check yet reads as
  # unchecked throughout.
  class DomainStatus
    # What the domain's MX records must be, exactly, for mail to arrive at the new host.
    EXPECTED_MX = [[10, "mail.gather.coop"], [20, "mail2.gather.coop"]].freeze

    # What the domain's SPF record must contain to authorize the new host. The full recommended
    # record is "v=spf1 include:_spf.gather.coop ~all", but a domain may legitimately carry other
    # mechanisms (e.g. for the community's own mail provider), so only the include is required.
    REQUIRED_SPF_INCLUDE = "include:_spf.gather.coop"

    # One SMTP2GO validation record plus whether we could see it in DNS at check time.
    ValidationRecord = Struct.new(:kind, :host, :target, :verified, :in_dns, keyword_init: true)

    attr_reader :domain, :check

    def initialize(domain:, check: nil)
      @domain = domain
      @check = check || domain.mail_migration_check
    end

    delegate :communities, to: :domain

    def checked?
      check.present?
    end

    def checked_at
      check&.checked_at
    end

    def mx
      checked? ? check.data["mx"] : []
    end

    def spf
      check&.data&.[]("spf")
    end

    def mx_ok?
      mx == EXPECTED_MX
    end

    def spf_ok?
      spf.present? && spf.include?(REQUIRED_SPF_INCLUDE)
    end

    # :verified / :pending / :not_added, :unknown when the SMTP2GO API couldn't be queried at
    # check time, or :unchecked when no check has run yet.
    def smtp2go_status
      checked? ? check.data["smtp2go_status"].to_sym : :unchecked
    end

    # Which SMTP host the domain's outbound mail goes through. Full SMTP2GO validation is treated
    # as the switchover point: once a domain is verified there, its mail is relayed via SMTP2GO.
    def sending_via
      case smtp2go_status
      when :verified then :smtp2go
      when :unknown then :unknown
      when :unchecked then :unchecked
      else :legacy
      end
    end

    def migrated?
      mx_ok? && spf_ok? && smtp2go_status == :verified
    end

    def validation_records
      return [] unless checked?
      check.data["validation_records"].map do |record|
        ValidationRecord.new(kind: record["kind"].to_sym, host: record["host"],
          target: record["target"], verified: record["verified"], in_dns: record["in_dns"])
      end
    end
  end
end
