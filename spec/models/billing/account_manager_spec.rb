# frozen_string_literal: true

require "rails_helper"

describe Billing::AccountManager do
  describe "#account_for" do
    let!(:household) { create(:household) }
    let!(:other_community) { create(:community) }

    context "when account exists" do
      it "returns account" do
        account = described_class.instance.account_for(household_id: household.id,
                                                       community_id: household.community_id)
        expect(account.household).to eq(household)
        expect(account.community).to eq(household.community)
        expect(Billing::Account.count).to eq(1)
      end
    end

    context "when account doesn't exist" do
      it "creates account" do
        described_class.instance.account_for(household_id: household.id, community_id: other_community.id)
        expect(Billing::Account.count).to eq(2)
        expect(Billing::Account.all.map(&:community)).to contain_exactly(household.community, other_community)
      end
    end
  end

  describe "#create_household_successful" do
    it "creates account on household create" do
      household = create(:household)
      expect(Billing::Account.count).to eq(1)
      expect(Billing::Account.first.household).to eq(household)
    end
  end
end
