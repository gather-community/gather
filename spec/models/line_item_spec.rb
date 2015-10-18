require 'rails_helper'

RSpec.describe LineItem, type: :model do
  let(:household){ create(:household) }

  context "on create" do
    it "updates household account balance" do
      bal = household.account_balance
      create(:line_item, household: household, amount: 1.23)
      expect(household.reload.account_balance - bal).to eq 1.23
    end
  end

  context "on destroy" do
    it "updates household account balance" do
      item = create(:line_item, household: household, amount: 1.23)
      bal = household.reload.account_balance
      item.destroy
      expect(household.reload.account_balance - bal).to eq -1.23
    end
  end
end
