# frozen_string_literal: true

require "rails_helper"

describe Subscription::ExchangeRate do
  it "is deliberately global (not tenant-scoped)" do
    expect(described_class.scoped_by_tenant?).to be(false)
  end

  it "requires a unique currency" do
    described_class.create!(currency: "eur", rate: BigDecimal("0.92"), fetched_at: Time.current)
    dup = described_class.new(currency: "eur", rate: BigDecimal("0.93"), fetched_at: Time.current)
    expect(dup).not_to be_valid
  end
end
