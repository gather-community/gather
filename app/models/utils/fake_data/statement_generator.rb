module Utils
  module FakeData
    class StatementGenerator < Generator
      attr_accessor :community

      def initialize(community:)
        self.community = community
      end

      def generate
        make_statements
        pay_bills
      end

      private

      def make_statements
        Billing::StatementJob.new(community.id).perform
      end

      def pay_bills
        # All but 4 accounts get paid up.
        Billing::Account.all.shuffle[0..-4].each do |acct|
          next if acct.balance_due <= 0
          Timecop.travel(rand(20).days) do
            acct.transactions.create!(
              amount: acct.balance_due,
              code: "payment",
              incurred_on: Date.today,
              description: "Check ##{rand(10000)}"
            )
          end
        end
      end
    end
  end
end
