# frozen_string_literal: true

require "rails_helper"

describe DomainMail::Checker do
  subject(:checker) do
    described_class.new(domains: domains, client: client, dns_checker: dns_checker)
  end

  let!(:domain) { create(:domain, name: "Example.COM") }
  let(:domains) { [domain] }
  let(:dns_checker) do
    instance_double(DomainMail::DnsChecker,
      mx_records: [[10, "mail.gather.coop"]], spf_record: "v=spf1 mx ~all", cname_target: nil)
  end

  context "when the client is configured" do
    let(:sender_domain) do
      Smtp2go::SenderDomain.new(name: "example.com", records: [
        Smtp2go::SenderDomain::DnsRecord.new(kind: :dkim, host: "s1._domainkey.example.com",
          target: "dkim.smtp2go.net", verified: true)
      ])
    end
    let(:client) do
      instance_double(Smtp2go::Client, configured?: true, sender_domains: [sender_domain])
    end

    it "stores a check row, matching SMTP2GO domains case-insensitively" do
      checker.run
      check = domain.reload.mail_check
      expect(check.checked_at).to be_within(1.minute).of(Time.current)
      expect(check.data["mx"]).to eq([[10, "mail.gather.coop"]])
      expect(check.data["spf"]).to eq("v=spf1 mx ~all")
      expect(check.data["spf_lookup_terms"]).to eq([{"term" => "mx", "via" => nil}])
      expect(check.data["smtp2go_status"]).to eq("verified")
      expect(check.data["validation_records"]).to eq([{
        "kind" => "dkim", "host" => "s1._domainkey.example.com", "target" => "dkim.smtp2go.net",
        "actual" => nil, "verified" => true, "in_dns" => false
      }])
    end

    it "updates the existing row on a re-check rather than creating another" do
      create(:domain_mail_check, domain: domain, checked_at: 1.day.ago)
      checker.run
      expect(DomainMail::Check.count).to eq(1)
      expect(domain.reload.mail_check.checked_at).to be_within(1.minute).of(Time.current)
    end

    it "marks in_dns true when our own CNAME lookup matches the expected target" do
      allow(dns_checker).to receive(:cname_target)
        .with("s1._domainkey.example.com").and_return("dkim.smtp2go.net")
      checker.run
      record = domain.reload.mail_check.data["validation_records"][0]
      expect(record["in_dns"]).to be(true)
      expect(record["actual"]).to eq("dkim.smtp2go.net")
    end

    context "with several domains" do
      let!(:domain2) { create(:domain, name: "other.example.org") }
      let(:domains) { [domain, domain2] }

      it "makes one API call and marks absent domains not_added" do
        checker.run
        expect(client).to have_received(:sender_domains).once
        expect(domain.reload.mail_check.data["smtp2go_status"]).to eq("verified")
        expect(domain2.reload.mail_check.data["smtp2go_status"]).to eq("not_added")
        expect(domain2.mail_check.data["validation_records"]).to eq([])
      end
    end
  end

  context "when the API key is not configured" do
    let(:client) { instance_double(Smtp2go::Client, configured?: false) }

    it "still stores the DNS results, with smtp2go_status unknown" do
      checker.run
      check = domain.reload.mail_check
      expect(check.data["smtp2go_status"]).to eq("unknown")
      expect(check.data["mx"]).to eq([[10, "mail.gather.coop"]])
      expect(checker.smtp2go_error).to eq(:not_configured)
    end
  end

  context "when the API request fails" do
    let(:client) { instance_double(Smtp2go::Client, configured?: true) }

    before do
      allow(client).to receive(:sender_domains).and_raise(Smtp2go::Client::RequestError, "boom")
    end

    it "reports to Sentry and stores DNS results with smtp2go_status unknown" do
      expect(Gather::ErrorReporter.instance).to receive(:report)
        .with(instance_of(Smtp2go::Client::RequestError), data: {context: "domain_mail_checker"})
      checker.run
      expect(domain.reload.mail_check.data["smtp2go_status"]).to eq("unknown")
      expect(checker.smtp2go_error).to eq(:request_failed)
    end
  end
end
