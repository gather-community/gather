# frozen_string_literal: true

require "rails_helper"

describe People::NotificationUnsubscribe do
  let(:user) { create(:user) }
  let(:kind) { People::NotificationCatalog.find(:meal_role_reminder) }
  let(:token) { described_class.token_for(user, kind) }

  it "round-trips a token" do
    unsubscribe = described_class.from_token(token)
    expect(unsubscribe.user).to eq(user)
    expect(unsubscribe.kind).to eq(kind)
    expect(unsubscribe.channel).to eq(:email)
  end

  it "uses URL-safe characters" do
    expect(token).to match(/\A[A-Za-z0-9_=-]+\z/)
  end

  it "turns off only that notification" do
    unsubscribe = described_class.from_token(token)
    expect(unsubscribe).not_to be_already_off
    unsubscribe.perform!
    user.reload
    expect(user.notification_enabled?(:meal_role_reminder)).to be(false)
    expect(user.notification_enabled?(:meal_reminder)).to be(true)
    expect(described_class.from_token(token)).to be_already_off
  end

  it "rejects a tampered token" do
    expect(described_class.from_token("#{token}x")).to be_nil
    expect(described_class.from_token("")).to be_nil
  end

  it "rejects a token from another cluster" do
    token # Build it in the user's own cluster first.
    other_cluster = create(:cluster)
    expect(with_tenant(other_cluster) { described_class.from_token(token) }).to be_nil
  end

  it "rejects a token for a deleted user" do
    token
    user.destroy
    expect(described_class.from_token(token)).to be_nil
  end

  it "rejects a token naming a required kind" do
    required = described_class.verifier.generate(
      {"c" => user.cluster_id, "u" => user.id, "k" => "meal_message", "ch" => "email"},
      purpose: described_class::PURPOSE
    )
    expect(described_class.from_token(required)).to be_nil
  end
end
