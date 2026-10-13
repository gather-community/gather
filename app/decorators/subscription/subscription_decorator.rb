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
      t("subscription.every_months", amount: total_per_invoice_fmtd, count: months_per_period)
    end

    def last_invoice_amount
      Money.from_cents(last_invoice_amount_cents, currency).format
    end

    def submit_button_label
      if no_invoice?
        t("subscription.pay_starting", amount: total_payment_with_months, date: I18n.l(start_date))
      else
        t("subscription.pay_now_and_then", now: last_invoice_amount, recurring: total_payment_with_months)
      end
    end
  end
end
