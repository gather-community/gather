# frozen_string_literal: true

require "rails_helper"

describe Stripe::WebhookEvent do
  describe ".record!" do
    it "stores the event id, type, and raw payload" do
      event = Stripe::Event.construct_from(id: "evt_123", type: "invoice.paid")
      payload = {"id" => "evt_123", "type" => "invoice.paid", "foo" => "bar"}

      record = described_class.record!(event, payload)

      expect(record.event_id).to eq("evt_123")
      expect(record.event_type).to eq("invoice.paid")
      expect(record.payload).to eq(payload)
    end
  end

  it "requires a payload" do
    expect(build(:stripe_webhook_event, payload: nil)).not_to be_valid
  end
end
