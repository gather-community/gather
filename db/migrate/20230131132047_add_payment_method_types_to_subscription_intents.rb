class AddPaymentMethodTypesToSubscriptionIntents < ActiveRecord::Migration[7.0]
  def up
    add_column :subscription_intents, :payment_method_types, :jsonb
    reversible do |dir|
      dir.up do
        execute("UPDATE subscription_intents SET payment_method_types = '[\"us_bank_account\"]'")
      end
    end
    change_column_null :subscription_intents, :payment_method_types, false
  end
end
