require 'rails_helper'

RSpec.describe Account, type: :model do
  let(:household){ create(:household) }
  let(:account){ Account.new(household) }

  context "no invoices or line items" do
    shared_examples_for "main household" do
      it "should be correct" do
        expect(account.last_invoice).to be_nil
        expect(account.total_new_credits).to eq 0
        expect(account.total_new_charges).to eq 0
        expect(account.outstanding_balance).to eq 0
        expect(account.current_balance).to eq 0
      end
    end

    context "no preload" do
      it_behaves_like "main household"
    end

    context "with preload" do
      let(:account) { Account.for_households([household]).first }

      it_behaves_like "main household"
    end
  end

  context "with invoices and items" do
    shared_examples_for "main household" do
      it "should be correct" do
        expect(account.last_invoice).to eq inv1
        expect(account.total_new_credits).to eq 12.45
        expect(account.total_new_charges).to eq 11.34
        expect(account.outstanding_balance).to eq 3.34
        expect(account.current_balance).to eq 14.68
      end
    end

    let(:inv1){ create(:invoice, household: household, prev_balance: 15.67) }
    let(:inv2){ create(:invoice, household: household) }
    let(:household2){ create(:household) }

    before do
      create(:line_item, household: household, amount: 0.12)
      inv1.populate!
      inv2.update_attribute(:created_at, 2.days.ago)
      create(:line_item, household: household, amount: 1.23)
      create(:line_item, household: household, amount: -4.56)
      create(:line_item, household: household, amount: -7.89)
      create(:line_item, household: household, amount: 10.11)

      create(:line_item, household: household2, amount: 1.23)
      build(:invoice, household: household2).populate!
    end

    context "no preload" do
      it_behaves_like "main household"
    end

    context "with preload" do
      let(:account) { Account.for_households([household, household2]).first }

      it_behaves_like "main household"
    end
  end
end
