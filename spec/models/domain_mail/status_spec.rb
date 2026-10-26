# frozen_string_literal: true

require "rails_helper"

describe DomainMail::Status do
  subject(:status) { described_class.new(domain: domain, check: check) }

  let(:domain) { build(:domain, name: "example.com") }
  let(:mx) { [[10, "mail.gather.coop"], [20, "mail2.gather.coop"]] }
  let(:spf) { "v=spf1 include:_spf.gather.coop ~all" }
  let(:smtp2go_status) { "verified" }
  let(:validation_records) { [] }
  let(:check) do
    DomainMail::Check.new(checked_at: Time.current, data: {
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

  describe "#smtp2go_status" do
    it "reads the stored status as a symbol" do
      expect(status.smtp2go_status).to eq(:verified)
    end

    context "when the SMTP2GO API couldn't be queried at check time" do
      let(:smtp2go_status) { "unknown" }

      it "is unknown" do
        expect(status.smtp2go_status).to eq(:unknown)
      end
    end
  end

  describe "#validation_records" do
    let(:validation_records) do
      [{"kind" => "dkim", "host" => "s1._domainkey.example.com", "target" => "dkim.smtp2go.net",
        "actual" => "something-else.example.net", "verified" => true, "in_dns" => false}]
    end

    it "builds structs with symbol kinds" do
      record = status.validation_records[0]
      expect(record.kind).to eq(:dkim)
      expect(record.host).to eq("s1._domainkey.example.com")
      expect(record.actual).to eq("something-else.example.net")
      expect(record.verified).to be(true)
      expect(record.in_dns).to be(false)
    end

    it "derives the display state from the verified and in_dns flags" do
      build = lambda do |verified, in_dns|
        described_class::ValidationRecord.new(kind: :dkim, host: "h", target: "t",
          verified: verified, in_dns: in_dns)
      end
      expect(build.call(true, true).state).to eq(:verified)
      expect(build.call(true, false).state).to eq(:verified)
      expect(build.call(false, true).state).to eq(:in_dns)
      expect(build.call(false, false).state).to eq(:missing)
    end
  end

  describe "#all_correct?" do
    it "is true when MX, SPF, and SMTP2GO validation are all in place" do
      expect(status).to be_all_correct
    end

    context "when SMTP2GO validation is pending" do
      let(:smtp2go_status) { "pending" }

      it "is false" do
        expect(status).not_to be_all_correct
      end
    end

    context "when the SPF record is absent (informational only)" do
      let(:spf) { nil }

      it "is still true" do
        expect(status).to be_all_correct
      end
    end
  end

  describe "with no check yet" do
    let(:check) { nil }

    before { allow(domain).to receive(:mail_check).and_return(nil) }

    it "reads as unchecked throughout" do
      expect(status).not_to be_checked
      expect(status.checked_at).to be_nil
      expect(status.mx).to eq([])
      expect(status.spf).to be_nil
      expect(status).not_to be_mx_ok
      expect(status).not_to be_all_correct
      expect(status.smtp2go_status).to eq(:unchecked)
      expect(status.validation_records).to eq([])
    end
  end
end
