# frozen_string_literal: true

module Messaging
  # A US community's 10DLC registration: the brand (the community's legal entity) and the campaign
  # (what it sends and how members opt in) that US carriers require before a community can text. One per
  # community. Created by the setup flow (Messaging::SetupForm) and moved along by
  # Messaging::RegistrationSubmitter as Telnyx and the carriers respond.
  #
  # Statuses, in order:
  #   draft            - details saved, setup not paid yet (e.g. the card was declined).
  #   awaiting_payment - setup charged, but the payment hasn't settled (e.g. ACH). Nothing goes to
  #                      Telnyx until it does, because Telnyx bills us the moment we submit.
  #   brand_pending    - brand submitted; waiting for Telnyx to verify it.
  #   campaign_pending - campaign submitted; waiting for carrier review (days to weeks).
  #   approved         - carriers approved the campaign.
  #   failed           - Telnyx or the carriers rejected the brand or campaign (see failure_reason).
  class Registration < ApplicationRecord
    STATUSES = %w[draft awaiting_payment brand_pending campaign_pending approved failed].freeze

    # Public companies also need a stock symbol and exchange, which we don't ask for; sole proprietors
    # can't send on behalf of a community. Both are left out on purpose.
    ENTITY_TYPES = %w[NON_PROFIT PRIVATE_PROFIT GOVERNMENT].freeze

    # Field lengths match Telnyx's limits for creating a brand.
    NAME_MAX = 100
    ADDRESS_MAX = 100
    EMAIL_MAX = 100
    PHONE_MAX = 20
    WEBSITE_MAX = 100
    POSTAL_CODE_MAX = 10
    EIN_MAX = 20

    acts_as_tenant :cluster

    encrypts :ein

    belongs_to :community, inverse_of: :messaging_registration

    # Records that the setup invoice has been paid, and starts submitting to Telnyx. Called when a card
    # payment succeeds during setup, and from the invoice.paid webhook for payments that settle later
    # (e.g. ACH). A no-op for an invoice that isn't a setup invoice, or one already recorded, so webhook
    # redeliveries are harmless.
    def self.payment_settled(stripe_invoice_id)
      return if stripe_invoice_id.blank?
      registration = ActsAsTenant.without_tenant { find_by(stripe_invoice_id: stripe_invoice_id) }
      return if registration.nil? || registration.paid_at.present?
      ActsAsTenant.with_tenant(registration.cluster) do
        registration.update!(paid_at: Time.current)
      end
      AdvanceRegistrationJob.perform_later(registration.id)
    end

    STATUSES.each do |s|
      define_method(:"#{s}?") { status == s }
    end

    # Whether the community has paid for setup, so it shouldn't be offered again.
    def paid?
      !draft?
    end

    # Whether Telnyx has the brand and the carriers are still to decide, or have decided.
    def submitted?
      submitted_at.present?
    end
  end
end
