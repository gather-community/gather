require 'rails_helper'

RSpec.describe Invoice, type: :model do
  let(:household){ create(:household) }

  describe "populate!" do
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

    it "should not raise if there are no relevant line items but balance is nonzero" do
      item1 = create(:line_item, household: household, incurred_on: "2015-01-01",
        amount: 1.23, invoice: create(:invoice))
      invoice = Invoice.new(household: household, prev_balance: -0.12)
      invoice.populate!
    end

    it "should raise if there are no relevant line items and balance is zero" do
      item1 = create(:line_item, household: household, incurred_on: "2015-01-01",
        amount: 1.23, invoice: create(:invoice))
      invoice = Invoice.new(household: household, prev_balance: 0)
      expect{invoice.populate!}.to raise_error(InvoiceError)
    end
  end
end
