# frozen_string_literal: true

# Builders for the Stripe object shapes introduced by the Basil API version (2025-03-31), which
# nested several fields our code reads. Keeping the shapes in one place means a future Stripe
# reshuffle is a change here rather than in every spec that fakes an invoice.
module StripeHelpers
  # An invoice carrying a PaymentIntent the Basil way: payments.data[n].payment.payment_intent.
  # Pass the PaymentIntent double (or an id string, to exercise the retrieve path).
  def stripe_invoice_double(payment_intent: nil, subscription: nil, lines: nil, **attrs)
    unless payment_intent.nil?
      attrs[:payments] = stripe_list_double([stripe_invoice_payment_double(payment_intent)])
    end
    unless subscription.nil?
      attrs[:parent] = double(subscription_details: double(subscription: subscription),
        type: "subscription_details")
    end
    attrs[:lines] = stripe_list_double(lines) unless lines.nil?
    double("Stripe::Invoice", **attrs)
  end

  def stripe_invoice_payment_double(payment_intent)
    double("Stripe::InvoicePayment", is_default: true,
      payment: double(payment_intent: payment_intent, type: "payment_intent"))
  end

  # A subscription whose billing period lives on its item, as Basil requires, and whose single item
  # carries the given price.
  def stripe_subscription_double(items: nil, current_period_end: nil, **attrs)
    items ||= [stripe_subscription_item_double(current_period_end: current_period_end)]
    double("Stripe::Subscription", items: stripe_list_double(items), **attrs)
  end

  def stripe_subscription_item_double(current_period_end: nil, price: nil, **attrs)
    double("Stripe::SubscriptionItem", current_period_end: current_period_end, price: price, **attrs)
  end

  # An invoice line item: the product moved under pricing.price_details, and the proration flag
  # under parent.subscription_item_details.
  def stripe_invoice_line_double(product: nil, proration: false, **attrs)
    double("Stripe::InvoiceLineItem",
      pricing: double(price_details: double(product: product, price: "price_test")),
      parent: double(subscription_item_details: double(proration: proration),
        invoice_item_details: nil, type: "subscription_item_details"),
      **attrs)
  end

  # A discount as Basil returns it: the coupon sits under `source`.
  def stripe_discount_double(percent_off:)
    double("Stripe::Discount", source: double(coupon: double(percent_off: percent_off),
      type: "coupon"))
  end

  def stripe_list_double(data)
    double("Stripe::ListObject", data: data, object: "list")
  end
end
