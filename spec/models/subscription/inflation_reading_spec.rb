# frozen_string_literal: true

require "rails_helper"

describe Subscription::InflationReading do
  it "is deliberately global (not tenant-scoped)" do
    expect(described_class.scoped_by_tenant?).to be(false)
  end

  it "requires a unique year" do
    described_class.create!(year: 2020, index_value: BigDecimal("258.8"), fetched_at: Time.current)
    dup = described_class.new(year: 2020, index_value: BigDecimal("259.0"), fetched_at: Time.current)
    expect(dup).not_to be_valid
  end
end
