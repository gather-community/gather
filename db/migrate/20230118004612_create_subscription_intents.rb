# frozen_string_literal: true

class CreateSubscriptionIntents < ActiveRecord::Migration[7.0]
  def change
    create_table :subscription_intents do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :community, foreign_key: true, index: {unique: true}, null: false
      t.string :contact_email, null: false
      t.integer :price_per_user_cents, null: false
      t.integer :quantity, null: false
      t.string :currency, null: false
      t.integer :months_per_period, null: false
      t.date :start_date, null: false
      t.string :address_city, null: false
      t.string :address_country, null: false
      t.string :address_line1, null: false
      t.string :address_line2
      t.string :address_postal_code
      t.string :address_state

      t.timestamps
    end
  end
end
