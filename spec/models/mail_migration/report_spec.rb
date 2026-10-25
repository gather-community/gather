# frozen_string_literal: true

require "rails_helper"

describe MailMigration::Report do
  subject(:report) do
    described_class.new(domains: [domain], client: client, dns_checker: dns_checker).generate
  end

  let(:domain) { build(:domain, name: "Example.COM") }
  let(:dns_checker) do
    instance_double(MailMigration::DnsChecker, mx_records: [], spf_record: nil, cname_target: nil)
  end

  context "when the client is configured" do
    let(:sender_domain) { Smtp2go::SenderDomain.new(name: "example.com", records: []) }
    let(:client) do
      instance_double(Smtp2go::Client, configured?: true, sender_domains: [sender_domain])
    end

    it "matches SMTP2GO domains to domains case-insensitively and reports no error" do
      expect(report.smtp2go_error).to be_nil
      expect(report.statuses.size).to eq(1)
      expect(report.statuses[0].smtp2go_status).to eq(:verified)
    end
  end

  context "when the API key is not configured" do
    let(:client) { instance_double(Smtp2go::Client, configured?: false) }

    it "sets the error and statuses degrade to unknown" do
      expect(report.smtp2go_error).to eq(:not_configured)
      expect(report.statuses[0].smtp2go_status).to eq(:unknown)
    end
  end

  context "when the API request fails" do
    let(:client) { instance_double(Smtp2go::Client, configured?: true) }

    before do
      allow(client).to receive(:sender_domains).and_raise(Smtp2go::Client::RequestError, "boom")
    end

    it "reports the error to Sentry, sets the error, and statuses degrade to unknown" do
      expect(Gather::ErrorReporter.instance).to receive(:report)
        .with(instance_of(Smtp2go::Client::RequestError), data: {context: "mail_migration_report"})
      expect(report.smtp2go_error).to eq(:request_failed)
      expect(report.statuses[0].smtp2go_status).to eq(:unknown)
    end
  end
end
