require 'rails_helper'

RSpec.describe Account, type: :model do
  let(:account){ create(:account, total_new_credits: 4, total_new_charges: 7) }
  let(:invoice){ create(:invoice, account: account) }

  describe "line_item_added" do
    it "should work for new charge" do
      create(:line_item, account: account, amount: 6)
      expect(account.reload.total_new_credits).to eq 4
      expect(account.total_new_charges).to eq 13
      expect(account.balance_due).to eq 4.81
      expect(account.current_balance).to eq 17.81
    end

    it "should work for new credit" do
      create(:line_item, account: account, amount: -6)
      expect(account.reload.total_new_credits).to eq 10
      expect(account.total_new_charges).to eq 7
      expect(account.balance_due).to eq -1.19
      expect(account.current_balance).to eq 5.81
    end
  end

  describe "invoice_added" do
    it "should update fields" do
      invoice
      expect(account.last_invoiced_on).to eq invoice.created_on
      expect(account.due_last_invoice).to eq invoice.total_due
      expect(account.last_invoice).to eq invoice
      expect(account.total_new_credits).to eq 0
      expect(account.total_new_charges).to eq 0
      expect(account.balance_due).to eq 9.99
      expect(account.current_balance).to eq 9.99
    end
  end

  describe "recalculate!" do
    it "should work with existing invoices and line items" do
      Timecop.travel(Date.today - 30.days) do
        @inv1 = create(:invoice, account: account, total_due: 10)
      end
      @inv2 = create(:invoice, account: account, total_due: 15)
      create(:line_item, account: account, amount: 5, invoice: @inv2)
      create(:line_item, account: account, amount: -8, invoice: @inv2)
      create(:line_item, account: account, amount: 4.5, invoice: @inv2)
      create(:line_item, account: account, amount: -2.35, invoice: @inv2)
      @inv2.destroy
      expect(account.last_invoiced_on).to eq @inv1.created_on
      expect(account.due_last_invoice).to eq 10
      expect(account.last_invoice).to eq @inv1
      expect(account.total_new_credits).to eq 10.35
      expect(account.total_new_charges).to eq 9.5
      expect(account.balance_due).to eq -0.35
      expect(account.current_balance).to eq 9.15
    end

    it "should work with no line items or invoices" do
      account.recalculate!
      expect(account.last_invoiced_on).to be_nil
      expect(account.due_last_invoice).to be_nil
      expect(account.last_invoice).to be_nil
      expect(account.total_new_credits).to eq 0
      expect(account.total_new_charges).to eq 0
      expect(account.balance_due).to eq 0
      expect(account.current_balance).to eq 0
    end
  end
end
