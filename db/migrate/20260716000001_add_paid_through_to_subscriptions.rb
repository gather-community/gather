# frozen_string_literal: true

# Caches the date the community has paid the subscription through — the period end of the most
# recent *successfully paid* invoice. Populated by Subscription#sync! (which the invoice.paid
# webhook already triggers). Groundwork for a later "out of paid time" access gate; nothing gates
# on it yet.
#
# This is deliberately not Stripe's current_period_end, which advances to the *unpaid* period as
# soon as a renewal invoice is created, and so can't answer "paid through when?" during dunning.
class AddPaidThroughToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :paid_through, :date
  end
end
