# frozen_string_literal: true

require "resolv"

module MailMigration
  # The DNS lookups the mail domain migration page needs. Lookup failures (NXDOMAIN, timeouts,
  # unreachable resolvers) are normal operation for a status page — the page reports what it can
  # see, and a transient failure just reads as "records not found" until the next load — so they
  # come back as empty results rather than raising.
  class DnsChecker
    TIMEOUT = 3 # seconds per query

    def initialize(resolver: nil)
      @resolver = resolver
    end

    # Returns [preference, exchange] pairs sorted by preference, e.g. [[10, "mail.gather.coop"]].
    # Hostnames are downcased with no trailing dot.
    def mx_records(domain)
      resources(domain, Resolv::DNS::Resource::IN::MX)
        .map { |record| [record.preference, normalize_name(record.exchange)] }
        .sort
    end

    # Returns the domain's SPF record (the first TXT record starting with v=spf1), or nil.
    # Long TXT records come back split into 255-byte strings, so the parts are joined first.
    def spf_record(domain)
      resources(domain, Resolv::DNS::Resource::IN::TXT)
        .map { |record| record.strings.join }
        .find { |string| string.match?(/\Av=spf1(\s|\z)/i) }
    end

    # Returns the host's CNAME target (downcased, no trailing dot), or nil if it has none.
    def cname_target(host)
      target = resources(host, Resolv::DNS::Resource::IN::CNAME).first
      target && normalize_name(target.name)
    end

    private

    def resources(name, type)
      resolver.getresources(name, type)
    rescue Resolv::ResolvError, Resolv::ResolvTimeout
      []
    end

    def resolver
      @resolver ||= Resolv::DNS.new.tap { |resolv| resolv.timeouts = TIMEOUT }
    end

    def normalize_name(name)
      name.to_s.downcase.delete_suffix(".")
    end
  end
end
