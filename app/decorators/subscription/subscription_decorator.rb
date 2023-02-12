# frozen_string_literal: true

module Subscription
  # Decorates subscriptions.
  class SubscriptionDecorator < ApplicationDecorator
    delegate_all

    def price_per_user
      Money.from_cents(price_per_user_cents, currency).format
    end

    def total_payment_with_months
      total_per_invoice_fmtd = Money.from_cents(total_per_invoice, currency).format
      months = h.pluralize(months_per_period, "month")
      "#{total_per_invoice_fmtd} every #{months}"
    end

    def last_invoice_amount
      Money.from_cents(last_invoice_amount_cents).format
    end
  end
end
