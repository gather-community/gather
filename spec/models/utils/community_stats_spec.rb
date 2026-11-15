# frozen_string_literal: true

require "rails_helper"

describe Utils::CommunityStats do
  let(:summarizer) { Utils::CommunitySummarizer.new }
  let(:stats) { described_class.new(communities: summarizer.with_status(Community.all)) }
  let!(:subscribed_cmty) { create(:community, name: "Subscribed") }
  let!(:trial_cmty) { create(:community, name: "Trial") }
  let!(:problem_cmty) { create(:community, name: "Problem") }

  before do
    # The default community (from the spec setup) is also a trial community.
    create(:subscription, community: subscribed_cmty, stripe_status: "active", synced_at: Time.current)
    create(:subscription, community: problem_cmty, stripe_status: "past_due", synced_at: Time.current)

    sub_guardian = create(:user, community: subscribed_cmty)
    create(:user, community: subscribed_cmty)
    create(:user, :child, community: subscribed_cmty, guardians: [sub_guardian])
    create(:user, :inactive, community: subscribed_cmty)
    create(:user, community: subscribed_cmty, fake: true)
    trial_guardian = create(:user, community: trial_cmty)
    create(:user, :child, community: trial_cmty, guardians: [trial_guardian])
    create(:user, :inactive, :child, community: trial_cmty, guardians: [trial_guardian])
  end

  it "counts communities by status" do
    expect(stats.status_count(:subscribed)).to eq(1)
    expect(stats.status_count(:trial)).to eq(2)
    expect(stats.status_count(:problem)).to eq(1)
    expect(stats.status_count(:deactivated)).to eq(0)
  end

  it "counts active, real users" do
    expect(stats.paying_users).to eq(2)
    expect(stats.adults).to eq(3)
    expect(stats.children).to eq(2)
  end

  it "counts years active including the first and current years" do
    Timecop.freeze(Date.new(2026, 11, 6)) do
      expect(stats.years_active).to eq(12)
    end
  end
end
