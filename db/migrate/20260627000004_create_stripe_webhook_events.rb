# frozen_string_literal: true

# Stores raw Stripe webhook payloads for prod debugging. Not tenant-scoped: payloads are
# saved on receipt, before the subscription (and thus the cluster) is resolved, and some
# events never map to a subscription at all.
class CreateStripeWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :stripe_webhook_events do |t|
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false
      t.timestamps
    end

    add_index :stripe_webhook_events, :event_id
  end
end
