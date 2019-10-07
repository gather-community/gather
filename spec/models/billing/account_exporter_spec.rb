# frozen_string_literal: true

require "rails_helper"

describe Billing::AccountExporter do
  let(:actor) { create(:biller) }
  let(:policy) do
    Billing::AccountPolicy.new(actor, Billing::Account.new(community: actor.community))
  end
  let(:exporter) { described_class.new(Billing::Account.all, policy: policy) }

  describe "to_csv" do
    context "with no accounts" do
      it "should return valid csv" do
        expect(exporter.to_csv).to eq("Number,Household ID,Household Name,Balance Due,Current Balance,"\
          "Credit Limit,Last Statement ID,Last Statement Date,Due Last Statement,Total New Charges,"\
          "Total New Credits,Creation Date\n")
      end
    end
  end
end
