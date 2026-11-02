# frozen_string_literal: true

module Messaging
  # The fixed fees a US community pays to text: 10DLC registration with The Campaign Registry, and
  # phone number rental. Telnyx passes these through at cost, and so do we (no markup), so a community
  # pays exactly what we're billed. All amounts are USD cents.
  #
  # Source: https://support.telnyx.com/en/articles/5634625-10dlc-fees-and-charges (TCR fees as of
  # 2025-07-22) and https://telnyx.com/pricing/messaging, checked 2026-11-02. Update this file when they
  # change; the setup page and the monthly billing read from here.
  module Fees
    # One-time, per brand.
    BRAND_REGISTRATION_CENTS = 450

    # Each carrier review of a campaign, including resubmissions after a rejection.
    CAMPAIGN_REVIEW_CENTS = 1500

    # The Low Volume Mixed campaign fee. Telnyx bills the first CAMPAIGN_PREPAID_MONTHS when the campaign
    # is registered, then monthly.
    CAMPAIGN_MONTHLY_CENTS = 150
    CAMPAIGN_PREPAID_MONTHS = 3

    # Renting a US local number. Charged monthly once the number is bought.
    NUMBER_MONTHLY_CENTS = 100

    CURRENCY = "usd"

    module_function

    # What a community pays to set up texting, as {key => cents}, in the order they're shown and debited.
    def setup_items
      {
        brand_registration: BRAND_REGISTRATION_CENTS,
        campaign_review: CAMPAIGN_REVIEW_CENTS,
        campaign_prepaid: CAMPAIGN_MONTHLY_CENTS * CAMPAIGN_PREPAID_MONTHS
      }
    end

    def setup_cents
      setup_items.values.sum
    end

    # The fixed part of each month's cost once a community is set up.
    def monthly_fixed_cents
      CAMPAIGN_MONTHLY_CENTS + NUMBER_MONTHLY_CENTS
    end
  end
end
