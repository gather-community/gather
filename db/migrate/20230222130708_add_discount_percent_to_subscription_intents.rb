class AddDiscountPercentToSubscriptionIntents < ActiveRecord::Migration[7.0]
  def change
    add_column :subscription_intents, :discount_percent, :decimal, precision: 6, scale: 2
  end
end
