# frozen_string_literal: true

require "rails_helper"

describe Subscription::SyncAllJob do
  include_context "jobs"

  it "syncs each community's subscription" do
    create(:subscription, community: Defaults.community)
    expect_any_instance_of(Subscription::Subscription).to receive(:sync!)
    perform_job
  end

  it "skips communities without a subscription" do
    Defaults.community
    expect_any_instance_of(Subscription::Subscription).not_to receive(:sync!)
    perform_job
  end

  # Backstop for a missed customer.subscription.deleted, which would otherwise strand a row pointing
  # at a canceled Stripe subscription — and that reads back as a healthy active topup.
  describe "reaping ended messaging topups" do
    let!(:topup) { create(:messaging_topup, community: Defaults.community) }

    before { allow_any_instance_of(Subscription::Subscription).to receive(:sync!) }

    def stub_topup_status(status)
      allow(Stripe::Subscription).to receive(:retrieve).and_return(
        stripe_subscription_double(status: status, cancel_at_period_end: false,
          items: [stripe_subscription_item_double], latest_invoice: nil)
      )
    end

    it "clears a topup whose Stripe subscription has ended" do
      stub_topup_status("canceled")
      expect { perform_job }.to change(Subscription::MessagingTopup, :count).by(-1)
    end

    it "keeps a live topup" do
      stub_topup_status("active")
      expect { perform_job }.not_to change(Subscription::MessagingTopup, :count)
    end

    # One failing community must not abort the nightly run, mirroring sync!.
    it "reports a Stripe error and carries on" do
      allow(Stripe::Subscription).to receive(:retrieve).and_raise(Stripe::APIError.new("boom"))
      expect(Gather::ErrorReporter.instance).to receive(:report)
      expect { perform_job }.not_to raise_error
    end
  end
end
