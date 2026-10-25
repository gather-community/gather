# frozen_string_literal: true

require "rails_helper"

describe Messaging::Providers::Base do
  # A throwaway subclass to exercise the shared behavior without depending on real rate figures.
  let(:provider) do
    Class.new(described_class) do
      def self.name = "Messaging::Providers::Acme"
      def self.rates = {"US" => "0.01", "CA" => "0.02"}
    end
  end

  describe ".rates" do
    it "is required of subclasses" do
      expect { described_class.rates }.to raise_error(NotImplementedError, /must define RATES/)
    end
  end

  describe ".key" do
    it "is the demodulized, underscored class name" do
      expect(provider.key).to eq(:acme)
    end
  end

  describe ".serves? / .countries" do
    it "reflects the rate table" do
      expect(provider.serves?("US")).to be(true)
      expect(provider.serves?("FR")).to be(false)
      expect(provider.countries).to contain_exactly("US", "CA")
    end
  end

  describe ".cost_per_segment" do
    it "returns the rate as a BigDecimal" do
      expect(provider.cost_per_segment("CA")).to eq(BigDecimal("0.02"))
    end

    it "raises for a country it doesn't carry" do
      expect { provider.cost_per_segment("FR") }.to raise_error(ArgumentError, /does not carry FR/)
    end
  end

  describe ".currency" do
    it "defaults to USD" do
      expect(provider.currency).to eq("USD")
    end
  end
end
