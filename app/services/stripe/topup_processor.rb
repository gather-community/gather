# frozen_string_literal: true

module Stripe
  # Reconciles a community's messaging wallet to a topup invoice's payment lifecycle. The wallet is
  # driven entirely by the invoice/payment, never the subscription's status:
  #
  #   * invoice.finalized, payment in-flight or already paid (PI processing/succeeded) -> credit.
  #     "processing" is how delayed methods (ACH/ACSS/SEPA) sit while funds move, so this optimistic
  #     credit makes them usable immediately. A declined/pending-first card finalizes UNPAID, so we
  #     don't credit it here.
  #   * invoice.paid -> credit (covers instant cards, and a retry success after a claw-back).
  #   * invoice.payment_failed / voided / marked_uncollectible -> claw back.
  #
  # A credit can flip credit -> claw-back -> re-credit across retries, so idempotency is state-based:
  # for each line we reconcile the wallet's net-for-that-line to the target (line.amount when
  # credited, 0 when not) and post only the delta. Redeliveries and out-of-order events converge.
  # We serialize per community on the Messaging::Account row so concurrent webhooks can't double-post.
  #
  # This class reopens the stripe gem's Stripe namespace, so app constants are referenced with a
  # leading :: (a bare `Subscription`, for instance, would resolve to the gem's Stripe::Subscription).
  class TopupProcessor
    CREDIT_DESCRIPTION = "Monthly messaging topup"
    REVERSAL_DESCRIPTION = "Reversal of uncollected messaging topup"
    CREDITED_PI_STATUSES = %w[processing succeeded].freeze

    # invoice is a Stripe invoice object; event is the originating webhook event when there is one
    # (nil when crediting synchronously from the save flow). Used for tracing.
    def initialize(invoice, event: nil)
      @invoice = invoice
      @event = event
    end

    # invoice.finalized (and the synchronous save): credit only if the payment is settled or in-flight.
    def credit_if_settled_or_in_flight
      credit if CREDITED_PI_STATUSES.include?(payment_intent_status)
    end

    # invoice.paid: the money arrived.
    def credit
      reconcile(credited: true)
    end

    # invoice.payment_failed / voided / marked_uncollectible: money isn't (or is no longer) coming.
    def claw_back
      reconcile(credited: false)
    end

    private

    attr_reader :event, :invoice

    def reconcile(credited:)
      lines = topup_lines
      return if lines.empty? # Not a messaging invoice; ignore (the common case).

      topup = find_topup
      if topup.nil?
        log(event_name: "topup_unmatched", description: "Topup invoice with no matching local record")
        return
      end

      ::ActsAsTenant.with_tenant(topup.cluster) do
        community = topup.community
        lines.each { |line| reconcile_line(community, line, credited: credited) }
      end
    end

    def reconcile_line(community, line, credited:)
      currency = account_currency(community, line)
      return if currency.nil?

      account = find_or_create_account(community, currency)
      # Lock the account row so concurrent events for this community reconcile serially.
      account.with_lock do
        net = account.transactions.where(stripe_invoice_line_item_id: line.id).sum(:amount_cents)
        target = credited ? line.amount : 0
        delta = target - net
        next if delta.zero? # Already in the desired state — idempotent no-op.
        post_transaction(account, line, delta)
      end
    end

    def post_transaction(account, line, delta)
      account.transactions.create!(
        amount_cents: delta,
        description: delta.positive? ? CREDIT_DESCRIPTION : REVERSAL_DESCRIPTION,
        stripe_invoice_line_item_id: line.id,
        stripe_event_id: event&.id
      )
      log(
        event_name: delta.positive? ? "topup_credited" : "topup_clawed_back",
        community_id: account.community_id,
        description: delta.positive? ? "Credited messaging topup" : "Clawed back messaging topup",
        amount_cents: delta, line_item: line.id
      )
    end

    def topup_lines
      product_id = ::Messaging::Account::PRODUCT_ID
      return [] if product_id.blank?
      invoice.lines.data.select { |line| line.price&.product == product_id }
    end

    def find_topup
      sub_id = invoice.subscription
      return nil if sub_id.blank?
      ::ActsAsTenant.without_tenant do
        ::Subscription::MessagingTopup.find_by(stripe_id: sub_id)
      end
    end

    def find_or_create_account(community, currency)
      ::Messaging::Account.find_or_create_by!(community: community) { |a| a.currency = currency }
    rescue ::ActiveRecord::RecordNotUnique
      # Raced another event creating the account for this community; the unique index means one won.
      ::Messaging::Account.find_by!(community: community)
    end

    # The PaymentIntent's status, retrieving it when the invoice only carries the id (webhook path);
    # the synchronous save path passes the invoice with payment_intent expanded.
    def payment_intent_status
      pi = invoice.payment_intent
      return nil if pi.nil?
      pi = ::Stripe::PaymentIntent.retrieve(pi) if pi.is_a?(String)
      pi.status
    end

    # Resolves the account currency, or nil (after logging) if it can't be determined or the Stripe
    # charge currency doesn't match — a mismatch means something is misconfigured.
    def account_currency(community, line)
      currency = community.default_currency
      if currency.blank?
        log(event_name: "topup_currency_missing", community_id: community.id,
          description: "No currency mapping for country_code=#{community.country_code}")
        return nil
      end
      if line.currency.present? && line.currency != currency
        log(event_name: "topup_currency_mismatch", community_id: community.id,
          description: "Line #{line.currency} != account #{currency}")
        return nil
      end
      currency
    end

    def log(event_name:, description:, community_id: nil, **data)
      ::Subscription::EventLog.emit(
        event_name: event_name, community_id: community_id, description: description,
        invoice_id: invoice.id, webhook_id: event&.id, **data
      )
    end
  end
end
