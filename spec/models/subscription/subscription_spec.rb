# frozen_string_literal: true

require "rails_helper"

describe Subscription::Subscription do
  it "has a valid factory" do
    create(:subscription)
  end
end
