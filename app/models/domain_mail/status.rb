# frozen_string_literal: true

module DomainMail
  # The mail status of one custom domain, read from its stored Check: whether its MX and SPF
  # records are correct, and whether SMTP2GO has validated it as a sender domain — including
  # whether the validation CNAME records were actually present in DNS at check time. A domain
  # with no stored check yet reads as unchecked throughout.
  class Status
    # What the domain's MX records must be, exactly, for mail to arrive at Gather's mail servers.
    EXPECTED_MX = [[10, "mail.gather.coop"], [20, "mail2.gather.coop"]].freeze

    # What the domain's own SPF record must contain. The full recommended record is
    # "v=spf1 include:_spf.gather.coop ~all", but a domain may legitimately carry other
    # mechanisms (e.g. the community's own mail provider), so only the include is required.
    REQUIRED_SPF_INCLUDE = "include:_spf.gather.coop"

    # One SMTP2GO validation record plus whether we could see it in DNS at check time.
    ValidationRecord = Struct.new(:kind, :host, :target, :actual, :verified, :in_dns,
      keyword_init: true) do
      # :verified — SMTP2GO has verified the record.
      # :in_dns — we found it in DNS, but SMTP2GO's periodic verification hasn't caught up yet.
      # :missing — not in DNS.
      def state
        if verified
          :verified
        elsif in_dns
          :in_dns
        else
          :missing
        end
      end
    end

    attr_reader :domain, :check

    def initialize(domain:, check: nil)
      @domain = domain
      @check = check || domain.mail_check
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

    # Whether every required record is correct: MX, SPF, and SMTP2GO validation.
    def all_correct?
      mx_ok? && spf_ok? && smtp2go_status == :verified
    end

    def validation_records
      return [] unless checked?
      check.data["validation_records"].map do |record|
        ValidationRecord.new(kind: record["kind"].to_sym, host: record["host"],
          target: record["target"], actual: record["actual"], verified: record["verified"],
          in_dns: record["in_dns"])
      end
    end
  end
end
