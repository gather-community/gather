# frozen_string_literal: true

require "rails_helper"

describe Billing::Transaction do
  describe "MANUALLY_ADDABLE_TYPES" do
    it "lists charges then credits, leaving out automatic-only types" do
      expect(described_class::MANUALLY_ADDABLE_TYPES.map(&:code))
        .to eq(%w[meal dues payout othchg payment reimb othcrd])
    end
  end

  describe "TYPES" do
    it "has a label for every type" do
      described_class::TYPES.each do |type|
        expect(I18n.exists?("transaction_codes.#{type.code}", :en)).to be(true), "No label for #{type.code}"
      end
    end
  end

  describe "payout" do
    let(:transaction) { build(:transaction, code: "payout", value: 25) }

    it "increases what the household owes" do
      expect(transaction).to be_increaser
      expect(transaction.amount).to eq(25)
      expect(transaction.chg_crd).to eq("charge")
    end
  end
end
