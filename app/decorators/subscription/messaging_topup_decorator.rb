# frozen_string_literal: true

module Subscription
  # Decorates a community's monthly messaging topup subscription for the subscription page.
  class MessagingTopupDecorator < ApplicationDecorator
    delegate_all

    # The amount the community has effectively chosen, in cents, or nil if none — which is the case
    # once a cancellation is pending, because from that point no further invoice is generated and so
    # nothing more will be billed or credited. Drives the topup row, the modal's preselected radio
    # and the Stimulus controller's change detection, so all three agree.
    def selected_cents
      canceling? ? nil : amount_cents
    end

    # e.g. "$5.00/month". Only meaningful when #selected_cents is present.
    def amount_display
      "#{Money.from_cents(amount_cents, currency).format}/month"
    end

    # Whether to show the Next Payment Date row. A pending cancellation leaves the status "active",
    # but the date it ends on is not a payment date: this period's invoice is already paid and no new
    # one will be generated. status_display says "Canceling on <date>" instead.
    def show_next_payment_date?
      active? && !canceling?
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
