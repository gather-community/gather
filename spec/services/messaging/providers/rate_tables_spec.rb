# frozen_string_literal: true

require "rails_helper"

# Locks the hardcoded rate figures so a careless edit trips a test, and documents which country
# sits with which provider and why. These are worst-case all-in USD costs per segment; update
# them (and the SOURCING comments in the provider classes) when the providers' rates move.
describe "Messaging provider rate tables" do
  describe Messaging::Providers::Telnyx do
    it "carries US/CA/AU/GB" do
      expect(described_class.countries).to contain_exactly("US", "CA", "AU", "GB")
    end

    it "prices the US at base plus the worst-case carrier fee" do
      # 0.004 base + 0.005 (US Cellular, dearest US carrier).
      expect(described_class.cost_per_segment("US")).to eq(BigDecimal("0.009"))
    end

    it "prices Canada at base plus its worst-case carrier fee" do
      # 0.0025 base + 0.008845 (Rogers/Fido, dearest CA send-side carrier fee).
      expect(described_class.cost_per_segment("CA")).to eq(BigDecimal("0.011345"))
    end

    it "prices AU and GB at their all-in figures (no separate carrier fees)" do
      expect(described_class.cost_per_segment("AU")).to eq(BigDecimal("0.05"))
      expect(described_class.cost_per_segment("GB")).to eq(BigDecimal("0.055"))
    end
  end
end
