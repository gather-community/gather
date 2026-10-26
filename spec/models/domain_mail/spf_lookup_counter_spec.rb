# frozen_string_literal: true

require "rails_helper"

describe DomainMail::SpfLookupCounter do
  subject(:counter) { described_class.new(dns_checker: dns_checker) }

  let(:nested_records) { {} }
  let(:dns_checker) do
    checker = instance_double(DomainMail::DnsChecker)
    allow(checker).to receive(:spf_record) { |domain| nested_records[domain] }
    checker
  end

  def terms_for(record)
    counter.count_terms(record).map { |t| [t["term"], t["via"]] }
  end

  it "counts a, mx, ptr, and exists but not ip4, ip6, or all" do
    expect(terms_for("v=spf1 a mx a:spf.example.com mx:mail.example.com/24 ptr " \
      "exists:%{ir}.x.example.com ip4:1.2.3.4 ip6:::1 ~all").size).to eq(6)
  end

  it "ignores qualifiers on mechanisms" do
    expect(terms_for("v=spf1 +a -mx ~include:other.example ?ptr -all").size).to eq(4)
  end

  context "with includes" do
    let(:nested_records) do
      {
        "one.example" => "v=spf1 mx include:two.example ~all",
        "two.example" => "v=spf1 a a:x.two.example ~all"
      }
    end

    it "recurses, attributing nested terms to the record they came from" do
      expect(terms_for("v=spf1 include:one.example ip4:1.2.3.4 ~all")).to eq([
        ["include:one.example", nil],
        ["mx", "one.example"],
        ["include:two.example", "one.example"],
        ["a", "two.example"],
        ["a:x.two.example", "two.example"]
      ])
    end
  end

  context "with a redirect modifier" do
    let(:nested_records) { {"other.example" => "v=spf1 mx ~all"} }

    it "counts the redirect and recurses" do
      expect(terms_for("v=spf1 redirect=other.example")).to eq([
        ["redirect=other.example", nil],
        ["mx", "other.example"]
      ])
    end
  end

  context "with a circular include chain" do
    let(:nested_records) do
      {
        "one.example" => "v=spf1 include:two.example ~all",
        "two.example" => "v=spf1 include:one.example ~all"
      }
    end

    it "counts repeated includes but descends into each domain only once, so it terminates" do
      expect(terms_for("v=spf1 include:one.example ~all")).to eq([
        ["include:one.example", nil],
        ["include:two.example", "one.example"],
        ["include:one.example", "two.example"]
      ])
    end
  end

  it "counts an include whose target uses a macro without recursing into it" do
    expect(dns_checker).not_to receive(:spf_record)
    expect(terms_for("v=spf1 include:%{i}.spf.example ~all").size).to eq(1)
  end

  it "counts an include whose target has no SPF record" do
    expect(terms_for("v=spf1 include:nothing.example ~all").size).to eq(1)
  end

  it "stops at MAX_TERMS on pathological records" do
    record = "v=spf1 #{"a " * 50}~all"
    expect(terms_for(record).size).to eq(described_class::MAX_TERMS)
  end
end
