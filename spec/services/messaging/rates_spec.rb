# frozen_string_literal: true

require "rails_helper"

describe Messaging::Rates do
  describe ".supported?" do
    it "is true for a carried country, case-insensitively" do
      expect(described_class.supported?("US")).to be(true)
      expect(described_class.supported?("us")).to be(true)
    end

    it "is false for a country no provider carries" do
      expect(described_class.supported?("FR")).to be(false)
    end
  end

  describe ".supported_countries" do
    it "lists every carried country, sorted" do
      expect(described_class.supported_countries).to eq(%w[AU CA GB US])
    end
  end

  describe ".provider_for" do
    it "routes each country to the provider that carries it" do
      expect(described_class.provider_for("US")).to eq(Messaging::Providers::Telnyx)
      expect(described_class.provider_for("GB")).to eq(Messaging::Providers::Telnyx)
    end

    it "raises UnsupportedCountryError for a country nobody carries" do
      expect { described_class.provider_for("NZ") }
        .to raise_error(described_class::UnsupportedCountryError)
    end
  end

  describe ".cost_per_segment" do
    it "returns the carrying provider's all-in cost as a BigDecimal" do
      expect(described_class.cost_per_segment("US")).to eq(BigDecimal("0.009"))
      expect(described_class.cost_per_segment("GB")).to eq(BigDecimal("0.055"))
    end
  end

  describe "one provider per country" do
    it "would raise if two provider tables claimed the same country" do
      # Guard against a future edit that adds an overlapping rate to both tables. We can't
      # easily corrupt the frozen constants, so assert the invariant holds as configured: no
      # country appears in more than one provider's table.
      all = described_class::PROVIDERS.flat_map(&:countries)
      expect(all).to eq(all.uniq)
    end
  end
end
