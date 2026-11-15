# frozen_string_literal: true

require "rails_helper"

describe Subscription::ExchangeRateClient do
  include WebMock::API

  # The webmock/rspec auto-reset isn't loaded globally (the suite uses VCR), so reset stubs and the
  # request counter after each example to keep counts accurate and avoid leaking stubs.
  after { WebMock.reset! }

  subject(:client) { described_class.new }

  let(:url) { "#{Settings.pricing.exchange_rate.base_url}/USD" }

  def stub_rates(body:, status: 200)
    stub_request(:get, url).to_return(status: status, body: body,
      headers: {"Content-Type" => "application/json"})
  end

  it "returns the rate for a currency" do
    stub_rates(body: {result: "success", rates: {"USD" => 1, "EUR" => 0.92, "JPY" => 150}}.to_json)
    expect(client.usd_rate("eur")).to eq(BigDecimal("0.92"))
    expect(client.usd_rate("jpy")).to eq(BigDecimal("150"))
  end

  it "fetches the full table only once across many currencies (memoized)" do
    stub_rates(body: {rates: {"EUR" => 0.92, "JPY" => 150}}.to_json)
    client.usd_rate("eur")
    client.usd_rate("jpy")
    assert_requested(:get, url, times: 1)
  end

  it "raises FetchError when the currency is missing from the table" do
    stub_rates(body: {rates: {"EUR" => 0.92}}.to_json)
    expect { client.usd_rate("xyz") }.to raise_error(Subscription::PricingDataFetcher::FetchError)
  end

  it "raises FetchError on a non-2xx response" do
    stub_rates(body: "nope", status: 502)
    expect { client.usd_rate("eur") }.to raise_error(Subscription::PricingDataFetcher::FetchError, /502/)
  end

  it "raises FetchError on a malformed body" do
    stub_rates(body: "{not json")
    expect { client.usd_rate("eur") }.to raise_error(Subscription::PricingDataFetcher::FetchError)
  end
end
