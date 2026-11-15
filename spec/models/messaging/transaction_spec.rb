# frozen_string_literal: true

require "rails_helper"

describe Messaging::Transaction do
  describe "validations" do
    it "requires amount_cents" do
      txn = build(:messaging_transaction, amount_cents: nil)
      expect(txn).not_to be_valid
      expect(txn.errors[:amount_cents]).to be_present
    end

    it "requires an integer amount_cents" do
      txn = build(:messaging_transaction, amount_cents: 1.5)
      expect(txn).not_to be_valid
      expect(txn.errors[:amount_cents]).to be_present
    end
  end

  describe "kind and description" do
    let(:account) { create(:messaging_account) }

    it "rejects an unknown kind" do
      expect { create(:messaging_transaction, account: account, kind: "bonus") }
        .to raise_error(ActiveRecord::StatementInvalid, /kind_valid/)
    end

    it "requires a description for a manual transaction and forbids one otherwise" do
      expect { create(:messaging_transaction, :manual, account: account, description: nil) }
        .to raise_error(ActiveRecord::StatementInvalid, /description_only_if_manual/)
      expect { create(:messaging_transaction, account: account, description: "Monthly messaging topup") }
        .to raise_error(ActiveRecord::StatementInvalid, /description_only_if_manual/)
    end

    it "describes system transactions in the reader's language and manual ones as written" do
      credit = create(:messaging_transaction, account: account, kind: "topup_credit")
      reversal = create(:messaging_transaction, account: account, kind: "topup_reversal",
        amount_cents: -1000)
      manual = create(:messaging_transaction, :manual, account: account)

      expect(credit.display_description).to eq("Monthly messaging topup")
      expect(reversal.display_description).to eq("Reversal of uncollected messaging topup")
      I18n.with_locale(:fr) do
        expect(credit.display_description).to eq(I18n.t("subscription.messaging_transactions.topup_credit"))
        expect(credit.display_description).not_to eq("Monthly messaging topup")
        expect(manual.display_description).to eq("Goodwill credit")
      end
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
