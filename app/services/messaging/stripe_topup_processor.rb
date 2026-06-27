# frozen_string_literal: true

module Messaging
  # Processes a Stripe `invoice.paid` event: if the invoice includes a paid line for the
  # recognized messaging top-up product, credits the community's messaging account with a
  # top-up transaction. Idempotent (keyed on the invoice line item id) so Stripe retries
  # are safe. Tenant is resolved from our own Subscription records, not from Stripe.
  class StripeTopupProcessor
    TOPUP_DESCRIPTION = "Messaging bundle top-up"

    def initialize(event)
      @event = event
      @invoice = event.data.object
    end

    def process
      lines = topup_lines
      return if lines.empty? # Not a messaging top-up; ignore (the common case).

      subscription = find_subscription
      if subscription.nil?
        report("Stripe messaging top-up invoice has no matching subscription")
        return
      end

      ActsAsTenant.with_tenant(subscription.cluster) do
        community = subscription.community
        lines.each { |line| credit(community, line) }
      end
    end

    private

    attr_reader :event, :invoice

    def topup_lines
      product_id = Messaging::Account::PRODUCT_ID
      return [] if product_id.blank?
      invoice.lines.data.select { |line| line.price&.product == product_id }
    end

    def find_subscription
      sub_id = invoice.subscription
      return nil if sub_id.blank?
      ActsAsTenant.without_tenant do
        Subscription::Subscription.find_by(stripe_id: sub_id)
      end
    end

    def credit(community, line)
      return if Messaging::Transaction.exists?(stripe_invoice_line_item_id: line.id)

      currency = account_currency(community, line)
      return if currency.nil?

      account = Messaging::Account.find_or_create_by!(community: community) do |a|
        a.currency = currency
      end
      account.transactions.create!(
        amount_cents: line.price.unit_amount,
        description: TOPUP_DESCRIPTION,
        stripe_invoice_line_item_id: line.id
      )
    end

    # Resolves the account currency for this community/line, or nil (after reporting) if it can't
    # be determined or the Stripe charge currency doesn't match. A mismatch means something is
    # misconfigured (e.g. a bundle priced in the wrong currency), so we give up rather than record
    # a top-up in the wrong currency.
    def account_currency(community, line)
      currency = Messaging::Account.currency_for(community)
      if currency.blank?
        report("No messaging currency mapping for country_code=#{community.country_code}")
        return nil
      end
      if line.currency.present? && line.currency != currency
        report("Stripe messaging top-up currency mismatch: line=#{line.currency} account=#{currency}")
        return nil
      end
      currency
    end

    def report(message)
      Gather::ErrorReporter.instance.report(
        StandardError.new(message),
        data: {stripe_event_id: event.id, event_type: event.type, invoice_id: invoice.id}
      )
    end
  end
end
