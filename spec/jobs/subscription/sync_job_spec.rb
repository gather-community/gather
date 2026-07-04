# frozen_string_literal: true

require "rails_helper"

describe Subscription::SyncJob do
  it "syncs the subscription within its cluster's tenant" do
    sub = create(:subscription, community: Defaults.community)
    expect_any_instance_of(Subscription::Subscription).to receive(:sync!)
    ActsAsTenant.without_tenant { described_class.perform_now(sub.id) }
  end

  it "is a no-op for an unknown subscription id" do
    ActsAsTenant.without_tenant do
      expect { described_class.perform_now(0) }.not_to raise_error
    end
  end
end
