# Applies late fees to a given community based on a policy.
module Billing
  class LateFeeApplier
    attr_accessor :community

    def initialize(community)
      self.community = community
    end

    def policy?
      policy.present?
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
          incurred_on: Date.today,
          code: "late",
          description: "Late payment fee",
          amount: amount_for(account.balance_due)
        )
      end
    end

    private

    def policy
      @policy ||= community.settings["late_fee_policy"]
    end

    def threshold
      policy["threshold"] || 0.0999
    end

    def amount_for(balance_due)
      case policy["fee_type"]
      when "fixed"
        raise "Late fee policy must have fee_amount if fee_type is 'fixed'" unless policy["fee_amount"]
        policy["fee_amount"]
      when "percent"
        raise "Late fee policy must have fee_pct if fee_type is 'percent'" unless policy["fee_pct"]
        (balance_due * policy["fee_pct"] / 100).round(2)
      else
        raise "Invalid fee_type '#{policy['fee_type']}'"
      end
    end
  end
end
