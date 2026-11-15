# frozen_string_literal: true

require "rails_helper"

describe Smtp2go::Client do
  include WebMock::API

  # The webmock/rspec auto-reset isn't loaded globally (the suite uses VCR), so reset stubs and the
  # request counter after each example to keep counts accurate and avoid leaking stubs.
  after { WebMock.reset! }

  subject(:client) { described_class.new }

  let(:url) { "#{Settings.smtp2go.base_url}/domain/view" }

  def stub_domain_view(body:, status: 200)
    stub_request(:post, url).to_return(status: status, body: body,
      headers: {"Content-Type" => "application/json"})
  end

  def domain_entry
    {
      "from_master" => false,
      "domain" => {
        "fulldomain" => "example.com",
        "dkim_selector" => "s123456", "dkim_verified" => true, "dkim_value" => "dkim.smtp2go.net",
        "rpath_selector" => "em7447", "rpath_verified" => false, "rpath_value" => "return.smtp2go.net"
      },
      "trackers" => [
        {"fulldomain" => "link.example.com", "cname_verified" => true,
         "cname_value" => "track.smtp2go.net", "enabled" => true}
      ]
    }
  end

  describe "#configured?" do
    it "is true when an API key is set (as in test settings)" do
      expect(client).to be_configured
    end

    it "is false when the key is blank" do
      allow(Settings).to receive(:smtp2go).and_return(double(api_key: nil))
      expect(client).not_to be_configured
    end
  end

  describe "#sender_domains" do
    it "sends the API key header and parses domains with their validation records" do
      stub_domain_view(body: {data: {domains: [domain_entry]}}.to_json)
      domains = client.sender_domains

      expect(domains.size).to eq(1)
      domain = domains[0]
      expect(domain.name).to eq("example.com")
      expect(domain).not_to be_verified

      expect(domain.records.map(&:kind)).to eq(%i[dkim return_path tracking])
      dkim, rpath, tracking = domain.records
      expect(dkim.host).to eq("s123456._domainkey.example.com")
      expect(dkim.target).to eq("dkim.smtp2go.net")
      expect(dkim.verified).to be(true)
      expect(rpath.host).to eq("em7447.example.com")
      expect(rpath.verified).to be(false)
      expect(tracking.host).to eq("link.example.com")
      expect(tracking.target).to eq("track.smtp2go.net")

      assert_requested(:post, url, times: 1) do |req|
        req.headers["X-Smtp2go-Api-Key"] == Settings.smtp2go.api_key
      end
    end

    it "reports a domain with all records verified as verified" do
      entry = domain_entry
      entry["domain"]["rpath_verified"] = true
      stub_domain_view(body: {data: {domains: [entry]}}.to_json)
      expect(client.sender_domains[0]).to be_verified
    end

    it "raises RequestError on a non-2xx response" do
      stub_domain_view(body: "nope", status: 401)
      expect { client.sender_domains }.to raise_error(described_class::RequestError, /401/)
    end

    it "raises RequestError on a malformed body" do
      stub_domain_view(body: "{not json")
      expect { client.sender_domains }.to raise_error(described_class::RequestError)
    end

    it "raises RequestError when the domains list is missing" do
      stub_domain_view(body: {data: {}}.to_json)
      expect { client.sender_domains }.to raise_error(described_class::RequestError, /malformed/)
    end
  end
end
