# frozen_string_literal: true

require "rails_helper"

describe Telnyx::Client do
  include WebMock::API

  # The webmock/rspec auto-reset isn't loaded globally (the suite uses VCR).
  after { WebMock.reset! }

  subject(:client) { described_class.new }

  let(:base) { Settings.telnyx.base_url }

  def json(body)
    {body: body.to_json, headers: {"Content-Type" => "application/json"}}
  end

  it "posts a brand with the bearer key and returns the top-level object" do
    # Stubbed with the expected body and headers, so a request that differs raises.
    stub_request(:post, "#{base}/10dlc/brand")
      .with(body: {displayName: "Sunny Hill"}.to_json,
        headers: {"Authorization" => "Bearer #{Settings.telnyx.api_key}",
                  "Content-Type" => "application/json"})
      .to_return(**json(brandId: "b1", identityStatus: "UNVERIFIED"))
    expect(client.create_brand(displayName: "Sunny Hill")).to eq("brandId" => "b1",
      "identityStatus" => "UNVERIFIED")
  end

  it "gets a campaign" do
    stub_request(:get, "#{base}/10dlc/campaign/c1").to_return(**json(campaignStatus: "TCR_PENDING"))
    expect(client.campaign("c1")).to eq("campaignStatus" => "TCR_PENDING")
  end

  it "raises with the status and body when Telnyx refuses a request" do
    stub_request(:post, "#{base}/10dlc/campaignBuilder").to_return(status: 422, body: '{"errors":[]}')
    expect { client.create_campaign(brandId: "b1") }.to raise_error(Telnyx::Client::RequestError) { |e|
      expect(e.status).to eq(422)
      expect(e.body).to eq('{"errors":[]}')
    }
  end

  it "raises without a status on a network failure" do
    stub_request(:get, "#{base}/10dlc/brand/b1").to_raise(SocketError.new("no route"))
    expect { client.brand("b1") }.to raise_error(Telnyx::Client::RequestError) { |e| expect(e.status).to be_nil }
  end
end
