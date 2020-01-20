# frozen_string_literal: true

require "rails_helper"

describe Domain do
  it "has a valid factory" do
    expect(create(:domain).communities.size).to eq(1)
  end
end
