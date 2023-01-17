# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :subscriptions do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :community, foreign_key: true, index: {unique: true}, null: false
      t.string :stripe_id
      t.string :contact_email
      t.decimal :price_per_user, precision: 10, scale: 2
      t.integer :quantity
      t.integer :months_per_period
      t.date :start_date
      t.string :currency
      t.check_constraint "(stripe_id IS NULL) != (contact_email IS NULL OR "\
        "price_per_user IS NULL OR quantity IS NULL OR months_per_period IS NULL OR "\
        "start_date IS NULL OR currency IS NULL)", name: "stripe_id_or_params"

      t.timestamps
    end
  end
end
