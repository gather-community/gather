require 'rails_helper'

module Billing
  describe LateFeeApplier do
    describe "apply" do
      let(:community){ create(:community, settings: { "late_fee_policy" => policy }) }
      let(:accounts) do
        [-5, 0, 5, 10, 15].map do |b|
          create(:account, community: community, due_last_statement: b, total_new_credits: 0)
        end
      end

      context "threshold with fixed fee" do
        let(:policy){ { "threshold" => 5, "fee_type" => "fixed", "fee_amount" => 3 } }

        it "should apply appropriate fees" do
          expect_fees(0, 0, 0, 3, 3)
        end
      end

      context "percent fee" do
        let(:policy){ { "fee_type" => "percent", "fee_pct" => 3 } }

        it "should apply appropriate fees" do
          expect_fees(0, 0, 0.15, 0.30, 0.45)
        end
      end

      context "no policy" do
        let(:policy){ nil }

        it "should apply no fees" do
          expect_fees(0, 0, 0, 0, 0)
        end
      end

      def expect_fees(*amounts)
        accounts
        LateFeeApplier.new(community).apply!
        amounts.each_with_index do |amt, i|
          if amt == 0
            expect(accounts[i].transactions).to be_empty
          else
            expect(accounts[i].transactions.last.incurred_on).to eq Date.today
            expect(accounts[i].transactions.last.code).to eq "late"
            expect(accounts[i].transactions.last.amount).to eq amt
          end
        end
      end
    end
  end
end
