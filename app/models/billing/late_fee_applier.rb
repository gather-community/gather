# frozen_string_literal: true

# Applies late fees to a given community based on a policy.
module Billing
  class LateFeeApplier
    attr_accessor :community

    def initialize(community)
      self.community = community
    end

    def policy?
      policy.fee_type != "none"
    end

    # Returns an AR relation for accounts that would receive late fees.
    def late_accounts
      return Billing::Account.none unless policy?

      Billing::Account.where(community: community).where("balance_due > ?", threshold)
    end

    def apply!
      return unless policy?

      late_accounts.each do |account|
        account.transactions.create!(
          incurred_on: Time.zone.today,
          code: "late",
          description: "Late payment fee",
          value: amount_for(account.balance_due)
        )
      end
    end

    private

    def policy
      @policy ||= community.settings.billing.late_fee_policy
    end

    def threshold
      policy.threshold || 0.0999
    end

    def amount_for(balance_due)
      case policy.fee_type
      when "fixed"
        raise "Late fee policy must have amount if fee_type is 'fixed'" unless policy.amount

        policy.amount
      when "percent"
        raise "Late fee policy must have amount if fee_type is 'percent'" unless policy.amount

        (balance_due * policy.amount / 100).round(2)
      else
        raise "Invalid fee_type '#{policy['fee_type']}'"
      end
    end
  end
end
