# frozen_string_literal: true

class RemoveCurrencyFromSubscriptionIntents < ActiveRecord::Migration[8.1]
  def change
    remove_column :subscription_intents, :currency, :string, null: false
  end
end
