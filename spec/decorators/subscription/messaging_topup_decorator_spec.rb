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

  describe "#selected_cents" do
    it "is the amount when the topup is running" do
      allow(topup).to receive_messages(canceling?: false, amount_cents: 1000)
      expect(decorator.selected_cents).to eq(1000)
    end

    # Once cancellation is pending no further invoice is generated, so the amount still sitting on the
    # Stripe item is not something the community has chosen or will be billed.
    it "is nil while a cancellation is pending" do
      allow(topup).to receive_messages(canceling?: true, amount_cents: 1000)
      expect(decorator.selected_cents).to be_nil
    end
  end

  describe "#show_next_payment_date?" do
    it "is true for a cleanly active topup" do
      allow(topup).to receive_messages(active?: true, canceling?: false)
      expect(decorator.show_next_payment_date?).to be(true)
    end

    # The status stays "active" during the wind-down, but that date is when it ends, not a payment
    # date: this period is already paid and no new invoice will be generated.
    it "is false while a cancellation is pending" do
      allow(topup).to receive_messages(active?: true, canceling?: true)
      expect(decorator.show_next_payment_date?).to be(false)
    end

    it "is false when the topup is not active" do
      allow(topup).to receive_messages(active?: false, canceling?: false)
      expect(decorator.show_next_payment_date?).to be(false)
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
