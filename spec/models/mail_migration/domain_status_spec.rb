# frozen_string_literal: true

require "rails_helper"

describe MailMigration::DomainStatus do
  subject(:status) do
    described_class.new(domain: domain, smtp2go_domain: smtp2go_domain,
      smtp2go_available: smtp2go_available, dns_checker: dns_checker)
  end

  let(:domain) { build(:domain, name: "example.com") }
  let(:smtp2go_available) { true }
  let(:smtp2go_domain) { nil }
  let(:mx) { [[10, "mail.gather.coop"], [20, "mail2.gather.coop"]] }
  let(:spf) { "v=spf1 include:_spf.gather.coop ~all" }
  let(:cname_targets) { {} }
  let(:dns_checker) do
    checker = instance_double(MailMigration::DnsChecker)
    allow(checker).to receive(:mx_records).with("example.com").and_return(mx)
    allow(checker).to receive(:spf_record).with("example.com").and_return(spf)
    allow(checker).to receive(:cname_target) { |host| cname_targets[host] }
    checker
  end

  def smtp2go_domain_with(dkim_verified: true, rpath_verified: true)
    Smtp2go::SenderDomain.new(name: "example.com", records: [
      Smtp2go::SenderDomain::DnsRecord.new(kind: :dkim, host: "s1._domainkey.example.com",
        target: "dkim.smtp2go.net", verified: dkim_verified),
      Smtp2go::SenderDomain::DnsRecord.new(kind: :return_path, host: "em1.example.com",
        target: "return.smtp2go.net", verified: rpath_verified)
    ])
  end

  describe "#mx_ok?" do
    it "is true when the records match the expected set exactly" do
      expect(status).to be_mx_ok
    end

    context "with an extra MX record" do
      let(:mx) { [[5, "old.example.com"], [10, "mail.gather.coop"], [20, "mail2.gather.coop"]] }

      it "is false" do
        expect(status).not_to be_mx_ok
      end
    end

    context "with no MX records" do
      let(:mx) { [] }

      it "is false" do
        expect(status).not_to be_mx_ok
      end
    end
  end

  describe "#spf_ok?" do
    it "is true when the SPF record contains the required include" do
      expect(status).to be_spf_ok
    end

    context "with other mechanisms alongside the required include" do
      let(:spf) { "v=spf1 include:_spf.google.com include:_spf.gather.coop ~all" }

      it "is true" do
        expect(status).to be_spf_ok
      end
    end

    context "without the required include" do
      let(:spf) { "v=spf1 include:_spf.oldhost.example ~all" }

      it "is false" do
        expect(status).not_to be_spf_ok
      end
    end

    context "with no SPF record" do
      let(:spf) { nil }

      it "is false" do
        expect(status).not_to be_spf_ok
      end
    end
  end

  describe "#smtp2go_status and #sending_via" do
    context "when the domain is not on the SMTP2GO account" do
      it "is not_added, sending via legacy" do
        expect(status.smtp2go_status).to eq(:not_added)
        expect(status.sending_via).to eq(:legacy)
      end
    end

    context "when some records are unverified" do
      let(:smtp2go_domain) { smtp2go_domain_with(rpath_verified: false) }

      it "is pending, sending via legacy" do
        expect(status.smtp2go_status).to eq(:pending)
        expect(status.sending_via).to eq(:legacy)
      end
    end

    context "when all records are verified" do
      let(:smtp2go_domain) { smtp2go_domain_with }

      it "is verified, sending via smtp2go" do
        expect(status.smtp2go_status).to eq(:verified)
        expect(status.sending_via).to eq(:smtp2go)
      end
    end

    context "when the SMTP2GO API couldn't be queried" do
      let(:smtp2go_available) { false }

      it "is unknown, sending via unknown" do
        expect(status.smtp2go_status).to eq(:unknown)
        expect(status.sending_via).to eq(:unknown)
      end
    end
  end

  describe "#validation_records" do
    context "when the domain is not on the SMTP2GO account" do
      it "is empty" do
        expect(status.validation_records).to be_empty
      end
    end

    context "with SMTP2GO records" do
      let(:smtp2go_domain) { smtp2go_domain_with(rpath_verified: false) }
      let(:cname_targets) { {"s1._domainkey.example.com" => "dkim.smtp2go.net"} }

      it "checks each record's presence in DNS independently of SMTP2GO's verified flag" do
        dkim, rpath = status.validation_records
        expect(dkim.in_dns).to be(true)
        expect(rpath.in_dns).to be(false)
      end
    end
  end

  describe "#migrated?" do
    context "when MX, SPF, and SMTP2GO validation are all in place" do
      let(:smtp2go_domain) { smtp2go_domain_with }

      it "is true" do
        expect(status).to be_migrated
      end
    end

    context "when SMTP2GO validation is pending" do
      let(:smtp2go_domain) { smtp2go_domain_with(dkim_verified: false) }

      it "is false" do
        expect(status).not_to be_migrated
      end
    end

    context "when the SPF record is outdated" do
      let(:smtp2go_domain) { smtp2go_domain_with }
      let(:spf) { "v=spf1 include:_spf.oldhost.example ~all" }

      it "is false" do
        expect(status).not_to be_migrated
      end
    end
  end
end
