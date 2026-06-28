# frozen_string_literal: true

require "rails_helper"

describe Messaging::Transaction do
  describe "validations" do
    it "requires a description and amount_cents" do
      txn = build(:messaging_transaction, description: nil, amount_cents: nil)
      expect(txn).not_to be_valid
      expect(txn.errors[:description]).to be_present
      expect(txn.errors[:amount_cents]).to be_present
    end

    it "requires an integer amount_cents" do
      txn = build(:messaging_transaction, amount_cents: 1.5)
      expect(txn).not_to be_valid
      expect(txn.errors[:amount_cents]).to be_present
    end
  end

  describe "associations" do
    it "delegates community to account and allows a nil (system) creator" do
      account = create(:messaging_account)
      txn = create(:messaging_transaction, account: account, creator: nil)
      expect(txn.creator).to be_nil
      expect(txn.community).to eq(account.community)
    end
  end
end
