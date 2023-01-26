# frozen_string_literal: true

require "rails_helper"

describe Subscription::Intent do
  it "has a valid factory" do
    create(:subscription_intent)
  end
end
