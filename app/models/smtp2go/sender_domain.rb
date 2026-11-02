# frozen_string_literal: true

module Smtp2go
  # The verification state of one sender domain, as reported by the SMTP2GO API. SMTP2GO validates
  # a domain via CNAME records the domain owner publishes (DKIM, return path, and link tracking);
  # this object exposes those expected records and whether SMTP2GO has verified each one.
  class SenderDomain
    # kind is :dkim, :return_path, or :tracking. host is the DNS name the owner must create and
    # target the value it must point at, both built from the API's per-domain selector/value fields
    # (which are authoritative; only the standard _domainkey label is assembled here).
    DnsRecord = Struct.new(:kind, :host, :target, :verified, keyword_init: true)

    attr_reader :name, :records

    # Builds from one entry of the domain/view endpoint's data.domains array.
    def self.from_api(entry)
      domain = entry["domain"]
      name = domain["fulldomain"]
      records = [
        DnsRecord.new(kind: :dkim, host: "#{domain["dkim_selector"]}._domainkey.#{name}",
          target: domain["dkim_value"], verified: domain["dkim_verified"] == true),
        DnsRecord.new(kind: :return_path, host: "#{domain["rpath_selector"]}.#{name}",
          target: domain["rpath_value"], verified: domain["rpath_verified"] == true)
      ]
      (entry["trackers"] || []).each do |tracker|
        records << DnsRecord.new(kind: :tracking, host: tracker["fulldomain"],
          target: tracker["cname_value"], verified: tracker["cname_verified"] == true)
      end
      new(name: name, records: records)
    end

    def initialize(name:, records:)
      @name = name
      @records = records
    end

    def verified?
      records.all?(&:verified)
    end
  end
end
