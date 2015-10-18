require 'rails_helper'

RSpec.describe Invoice, type: :model do
  describe "populate" do
    let(:household){ create(:household) }

    it "should populate properly" do
      item1 = create(:line_item, household: household, incurred_on: "2015-01-01", amount: 1.23)
      item2 = create(:line_item, household: household, incurred_on: "2015-01-02", amount: 2.34)
      item3 = create(:line_item, household: household, incurred_on: "2015-01-03", amount: 3.45)
      item4 = create(:line_item, household: household, incurred_on: "2015-01-06", amount: 4.56)
      invoice = Invoice.new(household: household, started_on: "2015-01-02",
        ended_on: "2015-01-05", prev_balance: -0.12)
      expect(invoice.populate!).to be true
      invoice.reload
      expect(invoice.line_items.sort_by(&:id)).to eq [item2, item3]
      expect(invoice.total_due).to eq 5.67
      expect(invoice.due_on).to eq Date.today + Invoice::TERMS
    end

    it "should not save on populate! if there are no relevant line items" do
      item1 = create(:line_item, household: household, incurred_on: "2015-01-01", amount: 1.23)
      invoice = Invoice.new(household: household, started_on: "2015-01-02",
        ended_on: "2015-01-05", prev_balance: -0.12)
      expect(invoice.populate!).to be false
      expect(invoice).not_to be_persisted
      expect(item1.reload.invoice).to be_nil
    end
  end
end
