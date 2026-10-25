# frozen_string_literal: true

module Stripe
  # Reads the two invoice fields that the Basil API version (2025-03-31) relocated, in one place so
  # the new shapes aren't spelled out at each of the several call sites that need them.
  #
  #   * invoice.subscription           -> invoice.parent.subscription_details.subscription
  #   * invoice.payment_intent         -> invoice.payments.data[n].payment.payment_intent
  #
  # Both readers tolerate the field being unexpanded: `payments` is only populated when the caller
  # expanded it, and `payment.payment_intent` is an id string unless expanded, so each falls back to
  # fetching. Callers that expand up front (see Subscription#populate) pay no extra request; the
  # webhook path, which gets whatever payload Stripe posted, does.
  #
  # This module reopens the stripe gem's Stripe namespace, so gem constants are referenced with a
  # leading :: to be explicit about what's being called.
  module InvoiceFields
    module_function

    # The id of the subscription that generated this invoice, or nil for a non-subscription invoice.
    def subscription_id(invoice)
      return nil if invoice.nil?
      invoice.parent&.subscription_details&.subscription
    end

    # The invoice's PaymentIntent as a full object, or nil when the invoice has no payment yet (a
    # $0 or not-yet-finalized invoice). Retrieves it when it isn't already expanded.
    def payment_intent(invoice)
      return nil if invoice.nil?
      intent = default_payment(invoice)&.payment&.payment_intent
      return nil if intent.nil?
      intent.is_a?(String) ? ::Stripe::PaymentIntent.retrieve(intent) : intent
    end

    # The invoice's default payment (Stripe marks one of possibly several attempts as the default),
    # listing them if the invoice didn't come with `payments` expanded.
    def default_payment(invoice)
      payments = invoice.payments&.data
      payments = ::Stripe::InvoicePayment.list(invoice: invoice.id).data if payments.blank?
      return nil if payments.blank?
      payments.find { |payment| payment.is_default } || payments.first
    end
  end
end
