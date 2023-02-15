class AddTierToSubscriptionIntents < ActiveRecord::Migration[7.0]
  def change
    add_column :subscription_intents, :tier, :string
    reversible do |dir|
      dir.up do
        execute("UPDATE subscription_intents SET tier = 'standard'")
      end
    end
    change_column_null :subscription_intents, :tier, false
  end
end
