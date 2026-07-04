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
end
