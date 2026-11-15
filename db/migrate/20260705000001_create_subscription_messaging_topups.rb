# frozen_string_literal: true

class CreateSubscriptionMessagingTopups < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_messaging_topups do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :community, null: false, foreign_key: true, index: {unique: true}
      t.string :stripe_id, null: false
      t.timestamps
    end
    add_index :subscription_messaging_topups, :stripe_id, unique: true
  end
end
