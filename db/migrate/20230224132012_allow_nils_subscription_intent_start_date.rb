class AllowNilsSubscriptionIntentStartDate < ActiveRecord::Migration[7.0]
  def change
    change_column_null :subscription_intents, :start_date, true
  end
end
