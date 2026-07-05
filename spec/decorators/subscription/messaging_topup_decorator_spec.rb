# frozen_string_literal: true

require "rails_helper"

describe Subscription::MessagingTopupDecorator do
  let(:topup) { build(:messaging_topup) }
  subject(:decorator) { topup.decorate }

  describe "#amount_display" do
    it "formats the monthly amount" do
      allow(topup).to receive_messages(amount_cents: 500, currency: "usd")
      expect(decorator.amount_display).to eq("$5.00/month")
    end
  end

  describe "#status_display" do
    it "is nil when the topup is cleanly active" do
      allow(topup).to receive_messages(canceling?: false, past_due?: false, payment_processing?: false)
      expect(decorator.status_display).to be_nil
    end

    it "reports a scheduled cancellation with the bill date" do
      allow(topup).to receive_messages(canceling?: true, next_bill_date: Date.new(2026, 8, 1))
      expect(decorator.status_display).to start_with("Canceling on")
    end

    it "reports past due" do
      allow(topup).to receive_messages(canceling?: false, past_due?: true)
      expect(decorator.status_display).to eq("Past due")
    end

    it "reports payment processing" do
      allow(topup).to receive_messages(canceling?: false, past_due?: false, payment_processing?: true)
      expect(decorator.status_display).to eq("Payment processing")
    end
  end
end
