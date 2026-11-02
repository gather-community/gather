# frozen_string_literal: true

require "rails_helper"

describe Messaging::RegistrationSubmitter do
  let(:client) { instance_double(Telnyx::Client) }
  let(:community) { Defaults.community }
  let(:registration) do
    create(:messaging_registration, community: community, status: "awaiting_payment",
      stripe_invoice_id: "in_setup", paid_at: Time.current)
  end
  subject(:submitter) { described_class.new(registration, client: client) }

  def balance_cents
    community.reload.messaging_account&.balance_cents || 0
  end

  def refused(status)
    Telnyx::Client::RequestError.new("refused", status: status, body: '{"errors":[{"detail":"Bad EIN"}]}')
  end

  describe "submitting the brand" do
    it "waits until the setup payment has settled" do
      registration.update!(paid_at: nil)
      expect(client).not_to receive(:create_brand)
      submitter.advance
      expect(registration.reload).to be_awaiting_payment
    end

    it "submits the brand details and debits the brand fee" do
      expect(client).to receive(:create_brand).with(hash_including(
        entityType: "NON_PROFIT", companyName: "Sunny Hill Cohousing Association", ein: "12-3456789",
        country: "US", phone: "+16075551234", vertical: "REAL_ESTATE"
      )).and_return("brandId" => "b1", "status" => "REGISTRATION_PENDING", "identityStatus" => "UNVERIFIED")
      submitter.advance
      registration.reload
      expect(registration).to be_brand_pending
      expect(registration.telnyx_brand_id).to eq("b1")
      expect(registration.submitted_at).to be_present
      expect(balance_cents).to eq(-450)
    end

    it "fails without charging when Telnyx refuses the brand" do
      expect(client).to receive(:create_brand).and_raise(refused(422))
      expect(Gather::ErrorReporter.instance).to receive(:report)
      submitter.advance
      expect(registration.reload).to be_failed
      expect(registration.failure_reason).to include("Bad EIN")
      expect(balance_cents).to eq(0)
    end

    it "raises on a transient failure so the job retries, leaving the registration as it was" do
      expect(client).to receive(:create_brand).and_raise(refused(503))
      expect { submitter.advance }.to raise_error(Telnyx::Client::RequestError)
      expect(registration.reload).to be_awaiting_payment
      expect(balance_cents).to eq(0)
    end
  end

  describe "waiting for brand verification" do
    before { registration.update!(status: "brand_pending", telnyx_brand_id: "b1") }

    it "does nothing while the brand is still pending" do
      expect(client).to receive(:brand).with("b1").and_return("status" => "REGISTRATION_PENDING")
      expect(client).not_to receive(:create_campaign)
      submitter.advance
      expect(registration.reload).to be_brand_pending
    end

    it "submits the campaign once the brand is verified, debiting the review fee and 3 months" do
      expect(client).to receive(:brand).and_return("status" => "OK", "identityStatus" => "VERIFIED")
      expect(client).to receive(:create_campaign).with(hash_including(brandId: "b1", usecase: "LOW_VOLUME"))
        .and_return("campaignId" => "c1", "campaignStatus" => "TCR_PENDING")
      submitter.advance
      registration.reload
      expect(registration).to be_campaign_pending
      expect(registration.telnyx_campaign_id).to eq("c1")
      expect(registration.campaign_version).to eq(1)
      expect(balance_cents).to eq(-1500 - 450)
    end

    it "fails when Telnyx can't verify the brand" do
      expect(client).to receive(:brand)
        .and_return("status" => "OK", "identityStatus" => "UNVERIFIED", "failureReasons" => "EIN mismatch")
      submitter.advance
      expect(registration.reload).to be_failed
      expect(registration.failure_reason).to eq("EIN mismatch")
    end
  end

  describe "waiting for carrier review" do
    before do
      registration.update!(status: "campaign_pending", telnyx_brand_id: "b1", telnyx_campaign_id: "c1")
    end

    it "records progress without changing status" do
      expect(client).to receive(:campaign).with("c1").and_return("campaignStatus" => "MNO_PENDING")
      submitter.advance
      expect(registration.reload).to be_campaign_pending
      expect(registration.campaign_status).to eq("MNO_PENDING")
    end

    it "approves once carriers provision the campaign" do
      expect(client).to receive(:campaign).and_return("campaignStatus" => "MNO_PROVISIONED")
      submitter.advance
      expect(registration.reload).to be_approved
      expect(registration.approved_at).to be_present
    end

    it "fails when carriers reject it" do
      expect(client).to receive(:campaign)
        .and_return("campaignStatus" => "MNO_REJECTED", "failureReasons" => "Opt-in unclear")
      submitter.advance
      expect(registration.reload).to be_failed
      expect(registration.failure_reason).to eq("Opt-in unclear")
    end
  end
end
