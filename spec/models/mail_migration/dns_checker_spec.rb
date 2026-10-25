# frozen_string_literal: true

require "rails_helper"

describe MailMigration::DnsChecker do
  subject(:checker) { described_class.new(resolver: resolver) }

  let(:resolver) { instance_double(Resolv::DNS) }

  def mx(preference, exchange)
    instance_double(Resolv::DNS::Resource::IN::MX, preference: preference,
      exchange: Resolv::DNS::Name.create(exchange))
  end

  def txt(*strings)
    instance_double(Resolv::DNS::Resource::IN::TXT, strings: strings)
  end

  describe "#mx_records" do
    it "returns [preference, exchange] pairs sorted by preference, normalized" do
      allow(resolver).to receive(:getresources).with("example.com", Resolv::DNS::Resource::IN::MX)
        .and_return([mx(20, "Mail2.Gather.Coop."), mx(10, "mail.gather.coop.")])
      expect(checker.mx_records("example.com"))
        .to eq([[10, "mail.gather.coop"], [20, "mail2.gather.coop"]])
    end

    it "returns [] when the lookup fails" do
      allow(resolver).to receive(:getresources).and_raise(Resolv::ResolvError)
      expect(checker.mx_records("example.com")).to eq([])
    end
  end

  describe "#spf_record" do
    it "returns the TXT record starting with v=spf1, joining split strings" do
      allow(resolver).to receive(:getresources).with("example.com", Resolv::DNS::Resource::IN::TXT)
        .and_return([
          txt("google-site-verification=abc"),
          txt("v=spf1 include:_spf.gather.coop", " ~all")
        ])
      expect(checker.spf_record("example.com")).to eq("v=spf1 include:_spf.gather.coop ~all")
    end

    it "does not match records that merely start with v=spf1 as a prefix of a longer token" do
      allow(resolver).to receive(:getresources).and_return([txt("v=spf10 whatever")])
      expect(checker.spf_record("example.com")).to be_nil
    end

    it "returns nil when there is no SPF record" do
      allow(resolver).to receive(:getresources).and_return([])
      expect(checker.spf_record("example.com")).to be_nil
    end
  end

  describe "#cname_target" do
    it "returns the normalized target" do
      cname = instance_double(Resolv::DNS::Resource::IN::CNAME,
        name: Resolv::DNS::Name.create("Return.SMTP2GO.net."))
      allow(resolver).to receive(:getresources)
        .with("em7447.example.com", Resolv::DNS::Resource::IN::CNAME).and_return([cname])
      expect(checker.cname_target("em7447.example.com")).to eq("return.smtp2go.net")
    end

    it "returns nil when the host has no CNAME" do
      allow(resolver).to receive(:getresources).and_return([])
      expect(checker.cname_target("em7447.example.com")).to be_nil
    end
  end
end
