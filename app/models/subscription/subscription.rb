# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id                              :bigint           not null, primary key
#  cluster_id                      :bigint           not null
#  community_id                    :bigint           not null
#  created_at                      :datetime         not null
#  paid_through                    :date
#  payment_intent_next_action_type :string
#  payment_intent_status           :string
#  setup_intent_next_action_type   :string
#  setup_intent_status             :string
#  stripe_id                       :string           not null
#  stripe_status                   :string
#  sync_error                      :string
#  synced_at                       :datetime
#  updated_at                      :datetime         not null
#
module Subscription
  # Models a subscription of Gather product itself.
  #
  # #detailed_status (derived below, purely from the cached columns) is the single source of truth
  # for "what's going on with this subscription" and drives what the /subscription page offers the
  # customer. The exhaustive set:
  #
  #   (no subscription)     Never subscribed, or fully reset      -> self-serve subscribe
  #   :incomplete           First invoice unpaid                   -> complete payment (Elements)
  #   :needs_payment_method Future-dated sub, no payment method    -> enter payment method
  #   :awaiting_microdeposits Bank verification pending            -> hosted verification URL
  #   :payment_processing   ACH/first payment settling             -> informational, wait
  #   :scheduled            Future-dated, payment method ready     -> informational
  #   :active               Healthy                                -> nothing (optionally update PM)
  #   :past_due             Renewal failed, Stripe retrying        -> revive: pay the open invoice
  #   :unpaid               Dunning exhausted, invoice still open  -> revive, else re-subscribe
  #   :incomplete_expired   First-payment window elapsed; dead     -> re-subscribe
  #   :canceled             Ended; dead                            -> re-subscribe
  #   :other                trialing/paused; Gather never produces these
  #   :unknown              Not yet synced                         -> resync
  #
  # Note "dead" vs "revivable": our Stripe dunning is configured to leave a failed sub *unpaid*
  # rather than cancel it, so past_due/unpaid keep a payable open invoice and can be revived in
  # place. Only incomplete_expired (abandoned first payment) and canceled (staff/scheduled cancel)
  # are terminal and require a brand-new subscription.
  class Subscription < ApplicationRecord
    # Override suffix
    self.table_name = "subscriptions"

    # The next_action type Stripe sets on a payment/setup intent whose bank account must be
    # verified via microdeposits (as opposed to generic 3DS-style authentication).
    MICRODEPOSITS = "verify_with_microdeposits"

    # detailed_status values that mean the community is a paying (or actively-onboarding) customer.
    GOOD_STANDING_STATUSES =
      %i[active scheduled needs_payment_method awaiting_microdeposits payment_processing incomplete].freeze

    # detailed_status values that mean a subscription exists but is not in good standing.
    PROBLEM_STATUSES = %i[incomplete_expired past_due unpaid canceled].freeze

    # Stripe subscription statuses that map directly to a detailed_status with no intent nuance.
    SIMPLE_STATUS_MAP = {
      "incomplete_expired" => :incomplete_expired,
      "past_due" => :past_due,
      "unpaid" => :unpaid,
      "canceled" => :canceled
    }.freeze

    acts_as_tenant :cluster

    attr_accessor :stripe_sub

    belongs_to :community, inverse_of: :subscription

    delegate :name, to: :community, prefix: true

    def registered?
      true
    end

    # Fetches data from Stripe
    def populate
      return if stripe_id.nil?
      self.stripe_sub = Stripe::Subscription.retrieve(
        id: stripe_id,
        expand: %w[customer.invoice_settings items.data.price.product latest_invoice.payment_intent
                   pending_setup_intent]
      )
      Rails.logger.info("Loaded subscription: #{stripe_sub}")
      stripe_sub
    end

    # Fetches live data from Stripe (via populate) and caches the key status signals locally so
    # that detailed_status/community-status can be computed without a Stripe call. This is the
    # single shared sync operation used by the nightly job, webhooks, page loads, the resync-all
    # action, and the inactivity job. Leaves stripe_sub populated for callers that need it.
    def sync!
      return if stripe_id.nil? || !persisted?
      populate
      update!(synced_attributes.merge(synced_at: Time.current, sync_error: nil))
      self
    rescue Stripe::StripeError => e
      update!(synced_at: Time.current, sync_error: e.message)
      Gather::ErrorReporter.instance.report(e, data: {subscription_id: id, community_id: community_id})
      self
    end

    # The exhaustive, human-meaningful subscription status, derived purely from the locally-cached
    # columns (no Stripe call). Separate from Community#status.
    def detailed_status
      self.class.derive_detailed_status(
        stripe_status: stripe_status,
        payment_intent_status: payment_intent_status,
        payment_intent_next_action_type: payment_intent_next_action_type,
        setup_intent_status: setup_intent_status,
        setup_intent_next_action_type: setup_intent_next_action_type,
        synced_at: synced_at
      )
    end

    # Pure mapping from the cached signal columns to a detailed_status symbol. Kept as a class
    # method taking raw values so Community can reuse it over summarizer-selected virtual attributes
    # without loading a Subscription. The two Stripe intent types are kept separate: a true
    # future-dated sub has a setup intent and no invoice; when both are present it's the brief lag
    # window of an invoiced sub whose just-saved payment method hasn't propagated to the invoice yet.
    def self.derive_detailed_status(stripe_status:, payment_intent_status:, payment_intent_next_action_type:,
      setup_intent_status:, setup_intent_next_action_type:, synced_at:)
      return :unknown if synced_at.nil? || stripe_status.nil?
      case stripe_status
      when "active"
        derive_active_status(payment_intent_status, payment_intent_next_action_type,
          setup_intent_status, setup_intent_next_action_type)
      when "incomplete"
        derive_incomplete_status(payment_intent_status, payment_intent_next_action_type)
      else
        SIMPLE_STATUS_MAP.fetch(stripe_status, :other) # :other = trialing/paused, never produced by Gather
      end
    end

    # active in Stripe: either a future-dated sub (setup intent, no invoice) or a normal invoiced sub.
    def self.derive_active_status(pi_status, pi_next_action, si_status, si_next_action)
      if si_status.present? && pi_status.blank?
        derive_future_active_status(si_status, si_next_action)
      else
        derive_invoiced_active_status(pi_status, pi_next_action, si_status)
      end
    end

    def self.derive_future_active_status(status, next_action_type)
      return :awaiting_microdeposits if next_action_type == MICRODEPOSITS
      case status
      when "processing" then :payment_processing # bank setup settling
      when "requires_payment_method" then :needs_payment_method # no payment method entered yet
      else :scheduled # payment method ready, awaiting the future start date
      end
    end

    def self.derive_invoiced_active_status(status, next_action_type, si_status)
      return :awaiting_microdeposits if next_action_type == MICRODEPOSITS
      # A processing payment intent on an *active* sub is a routine recurring renewal settling (ACH
      # takes days). The sub already collected its first payment — otherwise Stripe would still have it
      # as "incomplete" (we create with payment_behavior: default_incomplete) — so this is expected
      # background activity, not something to surface. First payments and future-dated setups still
      # report :payment_processing via the incomplete and setup-intent paths.
      # The payment-method-not-yet-attached lag edge (setup succeeded, invoice PI still needs a method).
      return :payment_processing if status == "requires_payment_method" && si_status == "succeeded"
      :active
    end

    # incomplete in Stripe is always invoiced (first invoice not yet paid).
    def self.derive_incomplete_status(status, next_action_type)
      return :awaiting_microdeposits if next_action_type == MICRODEPOSITS
      return :payment_processing if status == "processing"
      :incomplete
    end

    def subscription_good_standing?
      GOOD_STANDING_STATUSES.include?(detailed_status)
    end

    def subscription_problem?
      PROBLEM_STATUSES.include?(detailed_status)
    end

    def status
      stripe_sub&.status
    end

    def active?
      status == "active"
    end

    def incomplete?
      status == "incomplete"
    end

    def incomplete_expired?
      status == "incomplete_expired"
    end

    def past_due?
      status == "past_due"
    end

    def unpaid?
      status == "unpaid"
    end

    def canceled?
      status == "canceled"
    end

    # Even if a sub is active, it may still need a payment method.
    # This happens for subscriptions that start at a future date since we don't prorate
    # and don't do a $0 invoice, we instead use a SetupIntent, and so Stripe considers
    # the sub active even though the SetupIntent still hasn't been finished.
    # Whether a monthly messaging topup can be added/changed now: the base subscription must be a
    # live, invoiceable sub (active and not future-dated) with a saved payment method we can charge
    # immediately. Future-dated subs have no payment method attached yet, so they're excluded.
    def messaging_topup_editable?
      return false unless persisted? && active? && !future?
      default_payment_method_id.present?
    end

    # The payment method the topup subscription should reuse. We save it on the subscription itself
    # (save_default_payment_method: "on_subscription"), so prefer that; fall back to the customer's
    # invoice-settings default for older/hand-configured customers.
    def default_payment_method_id
      return nil if stripe_sub.nil?
      stripe_sub.default_payment_method || stripe_sub.customer&.invoice_settings&.default_payment_method
    end

    def needs_payment_method?
      return nil if stripe_sub.nil?
      active? && payment_or_setup_intent&.status == "requires_payment_method"
    end

    # PaymentIntent statuses we can still drive to completion from our own Elements form.
    CONFIRMABLE_PI_STATUSES = %w[requires_payment_method requires_action requires_confirmation].freeze

    # Whether an open invoice with a confirmable PaymentIntent exists — i.e. the customer can pay
    # this subscription's outstanding invoice in place and thereby fix it, rather than starting over.
    # This is what makes past_due/unpaid revivable: paying the open invoice returns the sub to
    # active, updating the payment method along the way.
    def payable_invoice?
      return false if stripe_sub.nil?
      invoice = stripe_sub.latest_invoice
      return false unless invoice&.status == "open"
      CONFIRMABLE_PI_STATUSES.include?(invoice.payment_intent&.status)
    end

    # Terminal in Stripe — can never be revived, so the only remedy is a brand-new subscription.
    # canceled and incomplete_expired are always dead; unpaid is dead only if dunning left no
    # payable invoice behind (with our "leave unpaid" setting it normally does).
    def dead?
      return false if stripe_sub.nil?
      canceled? || incomplete_expired? || (unpaid? && !payable_invoice?)
    end

    # Whether the customer can fix this subscription by paying an outstanding invoice.
    def revivable?
      (past_due? || unpaid? || incomplete?) && payable_invoice?
    end

    def payment_method_types
      return nil if stripe_sub.nil?
      payment_or_setup_intent.payment_method_types
    end

    def payment_requires_microdeposits?
      return nil if stripe_sub.nil?
      payment_or_setup_intent&.next_action&.type == "verify_with_microdeposits"
    end

    # Stripe's customer-facing explainer for micro-deposit verification.
    MICRODEPOSIT_HELP_URL =
      "https://support.stripe.com/questions/verify-a-new-ach-direct-debit-customer-using-micro-deposits"

    # Stripe's hosted page where the customer enters the microdeposit's descriptor code (or, for the
    # amount-based method, the deposit amounts) to verify their bank account. nil unless microdeposit
    # verification is pending.
    def microdeposit_verification_url
      return nil if stripe_sub.nil?
      action = payment_or_setup_intent&.next_action
      return nil unless action&.type == "verify_with_microdeposits"
      action.verify_with_microdeposits.hosted_verification_url
    end

    def contact_email
      return nil if stripe_sub.nil?
      stripe_sub.customer.email
    end

    def start_date
      return nil if stripe_sub.nil?
      stamp = backdated? ? stripe_sub.start_date : stripe_sub.billing_cycle_anchor
      Time.zone.at(stamp).to_date
    end

    def backdated?
      return nil if stripe_sub.nil?
      stripe_sub.start_date < stripe_sub.created
    end

    def future?
      no_invoice?
    end

    def no_invoice?
      return nil if stripe_sub.nil?
      # If subscription is post-dated, there won't be an invoice since we set proration_behavior to none.
      stripe_sub.latest_invoice.nil?
    end

    def next_payment_date
      return nil if stripe_sub.nil?
      Time.zone.at(stripe_sub&.current_period_end).to_date
    end

    def last_invoice_amount_cents
      return nil if stripe_sub.nil?
      return 0 if no_invoice?
      stripe_sub.latest_invoice.payment_intent.amount
    end

    def client_secret
      return nil if stripe_sub.nil?
      payment_or_setup_intent.client_secret
    end

    def months_per_period
      return nil if stripe_sub.nil?
      stripe_sub.items.data[0].price.recurring.interval_count
    end

    def price_per_user_cents
      return nil if stripe_sub.nil?
      stripe_sub.items.data[0].price.unit_amount / months_per_period
    end

    def total_per_invoice
      return nil if stripe_sub.nil?
      quantity * price_per_user_cents * months_per_period * (1 - (discount_percent || 0) / 100)
    end

    def currency
      return nil if stripe_sub.nil?
      stripe_sub.items.data[0].price.currency
    end

    def tier
      return nil if stripe_sub.nil?
      stripe_sub.items.data[0].price.product.metadata["tier"]
    end

    def quantity
      return nil if stripe_sub.nil?
      stripe_sub.items.data[0].quantity
    end

    def discount_percent
      return nil if stripe_sub.nil?
      stripe_sub.discount&.coupon&.percent_off
    end

    def address_line1
      return nil if stripe_sub.nil?
      stripe_sub.customer.address.line1
    end

    def address_line2
      return nil if stripe_sub.nil?
      stripe_sub.customer.address.line2
    end

    def address_city
      return nil if stripe_sub.nil?
      stripe_sub.customer.address.city
    end

    def address_state
      return nil if stripe_sub.nil?
      stripe_sub.customer.address.state
    end

    def address_postal_code
      return nil if stripe_sub.nil?
      stripe_sub.customer.address.postal_code
    end

    def address_country
      return nil if stripe_sub.nil?
      stripe_sub.customer.address.country
    end

    private

    # The signal columns cached from the live Stripe object during sync!.
    def synced_attributes
      pi = stripe_sub.latest_invoice&.payment_intent
      si = stripe_sub.pending_setup_intent
      attribs = {
        stripe_status: stripe_sub.status,
        payment_intent_status: pi&.status,
        payment_intent_next_action_type: pi&.next_action&.type,
        setup_intent_status: si&.status,
        setup_intent_next_action_type: si&.next_action&.type
      }
      # Only advance paid_through when there's actually a paid invoice to advance it to. A past_due
      # or unpaid sub's latest invoice is *not* paid, and must leave the last-paid date standing —
      # that date is precisely what says how much paid time they have left.
      paid = derive_paid_through
      paid.nil? ? attribs : attribs.merge(paid_through: paid)
    end

    # The period end of the most recent successfully-paid invoice, or nil if the latest invoice
    # isn't paid. The invoice's line period is used rather than the subscription's
    # current_period_end, which advances to the unpaid period the moment a renewal is invoiced.
    def derive_paid_through
      invoice = stripe_sub.latest_invoice
      return nil unless invoice&.status == "paid"
      stamp = invoice.lines&.data&.last&.period&.end
      stamp.nil? ? nil : Time.zone.at(stamp).to_date
    end

    def payment_or_setup_intent
      if no_invoice?
        stripe_sub.pending_setup_intent
      else
        stripe_sub.latest_invoice.payment_intent
      end
    end
  end
end
