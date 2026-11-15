# frozen_string_literal: true

# Caches key Stripe subscription state locally so the /communities index and community status
# can be computed without a live Stripe call per row. Populated by Subscription#sync!. The two
# Stripe intent types (PaymentIntent for invoiced subs, SetupIntent for future-dated subs) are
# stored in separate columns since they can briefly co-exist.
class AddStatusFieldsToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    change_table :subscriptions, bulk: true do |t|
      t.string :stripe_status
      t.string :payment_intent_status
      t.string :payment_intent_next_action_type
      t.string :setup_intent_status
      t.string :setup_intent_next_action_type
      t.datetime :synced_at
      t.string :sync_error
    end
  end
end
