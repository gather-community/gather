# frozen_string_literal: true

module Subscription
  # Decorates a community's monthly messaging topup subscription for the subscription page.
  class MessagingTopupDecorator < ApplicationDecorator
    delegate_all

    # e.g. "$5.00/month".
    def amount_display
      "#{Money.from_cents(amount_cents, currency).format}/month"
    end

    # A short status string shown only when the topup isn't cleanly active, else nil (row hidden).
    def status_display
      if canceling?
        "Canceling on #{I18n.l(next_bill_date)}"
      elsif past_due?
        "Past due"
      elsif payment_processing?
        "Payment processing"
      end
    end
  end
end
