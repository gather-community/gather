# frozen_string_literal: true

# Subscription::Intent is now an in-memory PORO built by the self-serve signup flow and consumed by
# Registrar, so there's nothing left to persist. The table only ever held staff-staged pricing that
# went stale the moment a subscription was registered (nothing deleted the row), which made it hard
# to tell what a community was actually on. Pricing now comes from PriceCalculator, and bespoke
# discounts should use Stripe coupons / promotion codes.
class DropSubscriptionIntents < ActiveRecord::Migration[8.1]
  def up
    drop_table :subscription_intents
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
