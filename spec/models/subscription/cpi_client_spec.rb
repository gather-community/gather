# frozen_string_literal: true

require "rails_helper"

describe Subscription::CpiClient do
  include WebMock::API

  after { WebMock.reset! }

  subject(:client) { described_class.new }

  let(:url) { Settings.pricing.cpi.base_url }

  def stub_cpi(data:, status: 200)
    body = {status: "REQUEST_SUCCEEDED", Results: {series: [{seriesID: "CUUR0000SA0", data: data}]}}
    stub_request(:post, url)
      .to_return(status: status, body: body.to_json, headers: {"Content-Type" => "application/json"})
  end

  describe "#annual_index" do
    it "returns the annual-average (M13) index for the year" do
      stub_cpi(data: [
        {year: "2020", period: "M13", periodName: "Annual", value: "258.811"},
        {year: "2020", period: "M12", periodName: "December", value: "260.474"}
      ])
      expect(client.annual_index(2020)).to eq(BigDecimal("258.811"))
    end

    it "raises FetchError when no annual figure is present" do
      stub_cpi(data: [{year: "2020", period: "M12", periodName: "December", value: "260.474"}])
      expect { client.annual_index(2020) }.to raise_error(Subscription::PricingDataFetcher::FetchError)
    end
  end

  describe "#latest_index" do
    it "returns [year, value] of the most recent monthly datapoint" do
      stub_cpi(data: [
        {year: "2026", period: "M05", periodName: "May", value: "320.500"},
        {year: "2026", period: "M04", periodName: "April", value: "319.100"}
      ])
      expect(client.latest_index).to eq([2026, BigDecimal("320.500")])
    end

    it "skips the annual (M13) row and takes the newest month" do
      stub_cpi(data: [
        {year: "2025", period: "M13", periodName: "Annual", value: "315.000"},
        {year: "2025", period: "M12", periodName: "December", value: "316.200"}
      ])
      expect(client.latest_index).to eq([2025, BigDecimal("316.200")])
    end

    it "skips gap points reported as '-' (e.g. a data-collection lapse)" do
      stub_cpi(data: [
        {year: "2026", period: "M06", periodName: "June", value: "-"},
        {year: "2026", period: "M05", periodName: "May", value: "335.123"}
      ])
      expect(client.latest_index).to eq([2026, BigDecimal("335.123")])
    end
  end

  it "raises FetchError on a non-2xx response" do
    stub_request(:post, url).to_return(status: 500, body: "")
    expect { client.latest_index }.to raise_error(Subscription::PricingDataFetcher::FetchError, /500/)
  end
end
