require 'rails_helper'

RSpec.describe Invoice, type: :model do
  let(:household){ create(:household) }

  context "on create" do
    it "updates household account balance" do
      bal = household.account_balance
      create(:invoice, household: household, total_due: 1.23)
      expect(household.reload.account_balance - bal).to eq 1.23
    end
  end

  context "on destroy" do
    it "updates household account balance" do
      invoice = create(:invoice, household: household, total_due: 1.23)
      bal = household.reload.account_balance
      invoice.destroy
      expect(household.reload.account_balance - bal).to eq -1.23
    end
  end

  describe "populate" do
    it "should populate properly" do
      item1 = create(:line_item, household: household, incurred_on: "2015-01-01",
        amount: 1.23, invoice: create(:invoice, household: household))
      item2 = create(:line_item, household: household, incurred_on: "2015-01-02", amount: 2.34)
      item3 = create(:line_item, household: household, incurred_on: "2015-01-03", amount: 3.45)
      item4 = create(:line_item, household: household, incurred_on: "2015-01-06", amount: 4.56)

      invoice = Invoice.new(household: household, prev_balance: -0.12)
      expect(invoice.populate!).to be true
      invoice.reload
      expect(invoice.line_items.sort_by(&:id)).to eq [item2, item3, item4]
      expect(invoice.total_due).to eq 10.23
      expect(invoice.due_on).to eq Date.today + Invoice::TERMS
    end

    it "should not save on populate! if there are no relevant line items" do
      item1 = create(:line_item, household: household, incurred_on: "2015-01-01",
        amount: 1.23, invoice: create(:invoice))
      invoice = Invoice.new(household: household, prev_balance: -0.12)
      expect(invoice.populate!).to be false
      expect(invoice).not_to be_persisted
    end
  end
end
