# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id                              :bigint           not null, primary key
#  cluster_id                      :bigint           not null
#  community_id                    :bigint           not null
#  created_at                      :datetime         not null
#  payment_intent_next_action_type :string
#  payment_intent_status           :string
#  setup_intent_next_action_type   :string
#  setup_intent_status             :string
#  stripe_id                       :string           not null
#  stripe_status                   :string
#  sync_error                      :string
#  synced_at                       :datetime
#  updated_at                      :datetime         not null
#
require "rails_helper"

describe Subscription::Subscription do
  it "has a valid factory" do
    create(:subscription)
  end

  describe ".derive_detailed_status" do
    def derive(**overrides)
      defaults = {stripe_status: "active", payment_intent_status: nil, payment_intent_next_action_type: nil,
                  setup_intent_status: nil, setup_intent_next_action_type: nil, synced_at: Time.current}
      described_class.derive_detailed_status(**defaults.merge(overrides))
    end

    it "is :unknown before first successful sync" do
      expect(derive(synced_at: nil)).to eq(:unknown)
      expect(derive(stripe_status: nil)).to eq(:unknown)
    end

    context "invoiced (active) sub" do
      it "is :active when paid and healthy" do
        expect(derive(stripe_status: "active", payment_intent_status: "succeeded")).to eq(:active)
      end

      it "stays :active while a routine recurring ACH renewal settles" do
        # An active sub has already collected its first payment, so a processing renewal is expected
        # background activity, not a surfaced 'processing' state.
        expect(derive(stripe_status: "active", payment_intent_status: "processing"))
          .to eq(:active)
      end

      it "is :awaiting_microdeposits when the payment intent needs bank verification" do
        expect(derive(stripe_status: "active", payment_intent_status: "requires_action",
          payment_intent_next_action_type: "verify_with_microdeposits")).to eq(:awaiting_microdeposits)
      end

      it "is :payment_processing in the payment-method-not-yet-attached lag edge" do
        expect(derive(stripe_status: "active", payment_intent_status: "requires_payment_method",
          setup_intent_status: "succeeded")).to eq(:payment_processing)
      end
    end

    context "future-dated (setup intent, no invoice) sub" do
      it "is :scheduled once the payment method is ready and awaiting the start date" do
        expect(derive(stripe_status: "active", setup_intent_status: "succeeded")).to eq(:scheduled)
      end

      it "is :needs_payment_method when no method has been entered" do
        expect(derive(stripe_status: "active", setup_intent_status: "requires_payment_method"))
          .to eq(:needs_payment_method)
      end

      it "is :payment_processing while the bank setup settles" do
        expect(derive(stripe_status: "active", setup_intent_status: "processing")).to eq(:payment_processing)
      end

      it "is :awaiting_microdeposits when the setup intent needs bank verification" do
        expect(derive(stripe_status: "active", setup_intent_status: "requires_action",
          setup_intent_next_action_type: "verify_with_microdeposits")).to eq(:awaiting_microdeposits)
      end
    end

    context "incomplete sub" do
      it "is :incomplete while awaiting the first payment" do
        expect(derive(stripe_status: "incomplete", payment_intent_status: "requires_payment_method"))
          .to eq(:incomplete)
      end

      it "is :payment_processing when the first ACH payment settles" do
        expect(derive(stripe_status: "incomplete", payment_intent_status: "processing"))
          .to eq(:payment_processing)
      end

      it "is :awaiting_microdeposits when awaiting bank verification" do
        expect(derive(stripe_status: "incomplete",
          payment_intent_next_action_type: "verify_with_microdeposits")).to eq(:awaiting_microdeposits)
      end
    end

    it "maps the simple terminal/problem statuses directly" do
      expect(derive(stripe_status: "incomplete_expired")).to eq(:incomplete_expired)
      expect(derive(stripe_status: "past_due")).to eq(:past_due)
      expect(derive(stripe_status: "unpaid")).to eq(:unpaid)
      expect(derive(stripe_status: "canceled")).to eq(:canceled)
    end

    it "is :other for statuses Gather never produces (trialing/paused)" do
      expect(derive(stripe_status: "trialing")).to eq(:other)
      expect(derive(stripe_status: "paused")).to eq(:other)
    end
  end

  describe "good-standing / problem predicates" do
    let(:sub) { build(:subscription, synced_at: Time.current) }

    it "treats active/scheduled/in-progress as good standing" do
      sub.stripe_status = "active"
      sub.payment_intent_status = "succeeded"
      expect(sub.subscription_good_standing?).to be(true)
      expect(sub.subscription_problem?).to be(false)
    end

    it "treats canceled/past_due/unpaid/expired as a problem" do
      sub.stripe_status = "past_due"
      expect(sub.subscription_problem?).to be(true)
      expect(sub.subscription_good_standing?).to be(false)
    end
  end

  describe "#sync!" do
    let(:sub) { create(:subscription) }

    def fake_stripe_sub(status:, payment_intent: nil, setup_intent: nil)
      double("Stripe::Subscription", status: status,
        latest_invoice: payment_intent && double(payment_intent: payment_intent),
        pending_setup_intent: setup_intent)
    end

    context "for an invoiced active subscription" do
      before do
        pi = double(status: "succeeded", next_action: nil)
        allow(Stripe::Subscription).to receive(:retrieve)
          .and_return(fake_stripe_sub(status: "active", payment_intent: pi))
      end

      it "caches the signal columns and computes :active" do
        sub.sync!
        sub.reload
        expect(sub.stripe_status).to eq("active")
        expect(sub.payment_intent_status).to eq("succeeded")
        expect(sub.setup_intent_status).to be_nil
        expect(sub.sync_error).to be_nil
        expect(sub.synced_at).to be_within(5.seconds).of(Time.current)
        expect(sub.detailed_status).to eq(:active)
      end
    end

    context "for a future-dated sub awaiting bank verification" do
      before do
        si = double(status: "requires_action", next_action: double(type: "verify_with_microdeposits"))
        allow(Stripe::Subscription).to receive(:retrieve)
          .and_return(fake_stripe_sub(status: "active", setup_intent: si))
      end

      it "caches the setup intent signals and computes :awaiting_microdeposits" do
        sub.sync!
        sub.reload
        expect(sub.setup_intent_status).to eq("requires_action")
        expect(sub.setup_intent_next_action_type).to eq("verify_with_microdeposits")
        expect(sub.payment_intent_status).to be_nil
        expect(sub.detailed_status).to eq(:awaiting_microdeposits)
      end
    end

    context "when Stripe raises" do
      let(:reporter) { instance_double(Gather::ErrorReporter, report: nil) }

      before do
        allow(Gather::ErrorReporter).to receive(:instance).and_return(reporter)
        allow(Stripe::Subscription).to receive(:retrieve).and_raise(Stripe::StripeError.new("boom"))
      end

      it "records the error, stamps synced_at, and reports to Sentry" do
        sub.sync!
        sub.reload
        expect(sub.sync_error).to eq("boom")
        expect(sub.synced_at).to be_within(5.seconds).of(Time.current)
        expect(reporter).to have_received(:report)
          .with(instance_of(Stripe::StripeError), data: hash_including(community_id: sub.community_id))
      end
    end

    it "no-ops on an unpersisted record" do
      expect(Stripe::Subscription).not_to receive(:retrieve)
      build(:subscription).sync!
    end
  end
end
