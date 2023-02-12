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

    def submit_button_label
      if no_invoice?
        "Pay #{total_payment_with_months} starting #{I18n.l(start_date)}"
      else
        "Pay #{last_invoice_amount} now and then #{total_payment_with_months} from now"
      end
    end
  end
end
