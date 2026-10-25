# frozen_string_literal: true

require "rails_helper"

describe MailMigration::DomainStatus do
  subject(:status) { described_class.new(domain: domain, check: check) }

  let(:domain) { build(:domain, name: "example.com") }
  let(:mx) { [[10, "mail.gather.coop"], [20, "mail2.gather.coop"]] }
  let(:spf) { "v=spf1 include:_spf.gather.coop ~all" }
  let(:smtp2go_status) { "verified" }
  let(:validation_records) { [] }
  let(:check) do
    MailMigration::DomainCheck.new(checked_at: Time.current, data: {
      "mx" => mx, "spf" => spf, "smtp2go_status" => smtp2go_status,
      "validation_records" => validation_records
    })
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
    context "when verified" do
      it "sends via smtp2go" do
        expect(status.smtp2go_status).to eq(:verified)
        expect(status.sending_via).to eq(:smtp2go)
      end
    end

    context "when pending" do
      let(:smtp2go_status) { "pending" }

      it "sends via legacy" do
        expect(status.sending_via).to eq(:legacy)
      end
    end

    context "when not added" do
      let(:smtp2go_status) { "not_added" }

      it "sends via legacy" do
        expect(status.sending_via).to eq(:legacy)
      end
    end

    context "when the SMTP2GO API couldn't be queried at check time" do
      let(:smtp2go_status) { "unknown" }

      it "is unknown" do
        expect(status.smtp2go_status).to eq(:unknown)
        expect(status.sending_via).to eq(:unknown)
      end
    end
  end

  describe "#validation_records" do
    let(:validation_records) do
      [{"kind" => "dkim", "host" => "s1._domainkey.example.com", "target" => "dkim.smtp2go.net",
        "verified" => true, "in_dns" => false}]
    end

    it "builds structs with symbol kinds" do
      record = status.validation_records[0]
      expect(record.kind).to eq(:dkim)
      expect(record.host).to eq("s1._domainkey.example.com")
      expect(record.verified).to be(true)
      expect(record.in_dns).to be(false)
    end
  end

  describe "#migrated?" do
    it "is true when MX, SPF, and SMTP2GO validation are all in place" do
      expect(status).to be_migrated
    end

    context "when SMTP2GO validation is pending" do
      let(:smtp2go_status) { "pending" }

      it "is false" do
        expect(status).not_to be_migrated
      end
    end

    context "when the SPF record is outdated" do
      let(:spf) { "v=spf1 include:_spf.oldhost.example ~all" }

      it "is false" do
        expect(status).not_to be_migrated
      end
    end
  end

  describe "with no check yet" do
    let(:check) { nil }

    before { allow(domain).to receive(:mail_migration_check).and_return(nil) }

    it "reads as unchecked throughout" do
      expect(status).not_to be_checked
      expect(status.checked_at).to be_nil
      expect(status.mx).to eq([])
      expect(status.spf).to be_nil
      expect(status).not_to be_mx_ok
      expect(status).not_to be_migrated
      expect(status.smtp2go_status).to eq(:unchecked)
      expect(status.sending_via).to eq(:unchecked)
      expect(status.validation_records).to eq([])
    end
  end
end
