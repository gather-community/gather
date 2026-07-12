# frozen_string_literal: true

module Stripe
  # Processes Stripe invoice webhooks for the monthly messaging topup: credits a community's
  # Messaging::Account wallet when a topup invoice *finalizes* (so slow ACH payments don't delay
  # usable credit), and reverses that credit with an offsetting transaction when Stripe gives up
  # collecting. "Gives up" has two shapes depending on the account's failed-payment setting: the
  # invoice is marked uncollectible/voided, OR the subscription itself is canceled with the invoice
  # left unpaid (Stripe's default) — handle_topup_cancellation covers the latter. Everything is
  # idempotent so Stripe retries are safe. Tenant/community is resolved from our own
  # Subscription::MessagingTopup records — the topup is its own Stripe subscription, so its invoices
  # carry the messaging product's line.
  #
  # This class reopens the stripe gem's Stripe namespace, so app constants are referenced with a
  # leading :: (a bare `Subscription`, for instance, would resolve to the gem's Stripe::Subscription).
  class TopupProcessor
    CREDIT_DESCRIPTION = "Monthly messaging topup"
    REVERSAL_DESCRIPTION = "Reversal of uncollected messaging topup"

    # Handles a topup subscription being canceled (customer.subscription.deleted) — e.g. Stripe's
    # dunning canceling it after a failed payment. Any invoice we credited that's still unpaid is
    # reversed and voided, then the local record is removed so the community shows no topup (and can
    # add a fresh one). A normal end-of-cycle cancellation (from a user removal) has only paid
    # invoices, so nothing is reversed or voided.
    def self.handle_topup_cancellation(subscription_id)
      topup = ::ActsAsTenant.without_tenant do
        ::Subscription::MessagingTopup.find_by(stripe_id: subscription_id)
      end
      return if topup.nil?

      ::Stripe::Invoice.list(subscription: subscription_id, status: "open").data.each do |invoice|
        new(invoice).reverse # idempotent; only reverses lines we actually credited
        ::Stripe::Invoice.void_invoice(invoice.id) # abandon it in Stripe (fires invoice.voided, a no-op)
      end
      ::ActsAsTenant.with_tenant(topup.cluster) { topup.destroy! }
    end

    # invoice is a Stripe invoice object; event is the originating webhook event when there is one
    # (nil when crediting synchronously from the save flow — used only for error reporting).
    def initialize(invoice, event: nil)
      @invoice = invoice
      @event = event
    end

    # Credits the wallet for each messaging line on a finalized invoice.
    def credit
      each_topup_line(report_missing: true) { |community, line| credit_line(community, line) }
    end

    # Reverses those credits when the invoice is abandoned. report_missing is false because a missing
    # local record here is legitimate — e.g. our own void (from handle_topup_cancellation) fires an
    # invoice.voided after the record is already gone; there is simply nothing to reverse.
    def reverse
      each_topup_line(report_missing: false) { |_community, line| reverse_line(line) }
    end

    private

    attr_reader :event, :invoice

    def each_topup_line(report_missing:)
      lines = topup_lines
      return if lines.empty? # Not a messaging invoice; ignore (the common case).

      topup = find_topup
      if topup.nil?
        report("Stripe messaging invoice has no matching topup subscription") if report_missing
        return
      end

      ::ActsAsTenant.with_tenant(topup.cluster) do
        community = topup.community
        lines.each { |line| yield(community, line) }
      end
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

    def credit_line(community, line)
      return if ::Messaging::Transaction.exists?(stripe_invoice_line_item_id: line.id)

      currency = account_currency(community, line)
      return if currency.nil?

      account = ::Messaging::Account.find_or_create_by!(community: community) do |a|
        a.currency = currency
      end
      account.transactions.create!(
        # line.amount is what was actually invoiced (proration-correct), unlike price.unit_amount.
        amount_cents: line.amount,
        description: CREDIT_DESCRIPTION,
        stripe_invoice_line_item_id: line.id
      )
    rescue ::ActiveRecord::RecordNotUnique
      # Raced with the webhook (or a retry) crediting the same line — the unique index on
      # stripe_invoice_line_item_id already recorded it. Nothing more to do.
      nil
    end

    def reverse_line(line)
      reversal_key = "#{line.id}:reversal"
      return if ::Messaging::Transaction.exists?(stripe_invoice_line_item_id: reversal_key)

      # Reverse the exact amount we credited. If nothing was credited (e.g. the finalize event never
      # reached us), there's nothing to undo.
      original = ::Messaging::Transaction.find_by(stripe_invoice_line_item_id: line.id)
      return if original.nil?

      original.account.transactions.create!(
        amount_cents: -original.amount_cents,
        description: REVERSAL_DESCRIPTION,
        stripe_invoice_line_item_id: reversal_key
      )
    end

    # Resolves the account currency for this community/line, or nil (after reporting) if it can't be
    # determined or the Stripe charge currency doesn't match. A mismatch means something is
    # misconfigured, so we give up rather than record a credit in the wrong currency.
    def account_currency(community, line)
      currency = community.default_currency
      if currency.blank?
        report("No messaging currency mapping for country_code=#{community.country_code}")
        return nil
      end
      if line.currency.present? && line.currency != currency
        report("Stripe messaging topup currency mismatch: line=#{line.currency} account=#{currency}")
        return nil
      end
      currency
    end

    def report(message)
      data = {invoice_id: invoice.id}
      data.merge!(stripe_event_id: event.id, event_type: event.type) if event
      ::Gather::ErrorReporter.instance.report(StandardError.new(message), data: data)
    end
  end
end
