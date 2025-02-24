# frozen_string_literal: true

module Utils
  module Generators
    class StatementGenerator < Generator
      attr_accessor :community

      def initialize(community:)
        self.community = community
      end

      def generate_samples
        make_statements
        pay_bills
      end

      private

      def make_statements
        Billing::StatementJob.perform_now(community.id, no_mail: true)
      end

      def pay_bills
        # All but 4 accounts get paid up.
        Billing::Account.all.shuffle[0..-4].each do |acct|
          next if acct.balance_due <= 0

          Timecop.freeze(rand(20).days) do
            acct.transactions.create!(
              value: acct.balance_due,
              code: "payment",
              incurred_on: Time.zone.today,
              description: "Check ##{rand(10_000)}",
              created_at: community.created_at,
              updated_at: community.updated_at
            )
          end
        end
      end
    end
  end
end
