# frozen_string_literal: true

# Global (non-tenant) caches of the external data the self-serve pricing calculator needs:
# USD->currency exchange rates and US CPI index readings. Both are identical across every
# cluster, so like Stripe::WebhookEvent they are deliberately NOT tenant-scoped. Populated by
# Subscription::RefreshPricingDataJob (nightly) with a synchronous fetch fallback.
class CreateSubscriptionPricingDataTables < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_exchange_rates do |t|
      t.string :currency, null: false
      t.decimal :rate, precision: 18, scale: 8, null: false
      t.datetime :fetched_at, null: false
      t.timestamps
    end
    add_index :subscription_exchange_rates, :currency, unique: true

    create_table :subscription_inflation_readings do |t|
      t.integer :year, null: false
      t.decimal :index_value, precision: 12, scale: 4, null: false
      t.datetime :fetched_at, null: false
      t.timestamps
    end
    add_index :subscription_inflation_readings, :year, unique: true
  end
end
