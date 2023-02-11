# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[7.0]
  def change
    stub_fields = %i[contact_email price_per_user_cents quantity currency months_per_period 
      start_date address_city address_country address_line1 address_line2 address_postal_code address_state
    ]
    optional_stub_fields = %i[address_line2 address_postal_code address_state]
    required_stub_fields_not_null = (stub_fields - optional_stub_fields).map { |f| "#{f} IS NOT NULL" }.join(" AND ")
    all_stub_fields_null = stub_fields.map { |f| "#{f} IS NULL" }.join(" AND ")

    create_table :subscriptions do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :community, foreign_key: true, index: {unique: true}, null: false
      t.string :stripe_id
      t.string :contact_email
      t.integer :price_per_user_cents
      t.integer :quantity
      t.string :currency
      t.integer :months_per_period
      t.date :start_date
      t.string :address_city
      t.string :address_country
      t.string :address_line1
      t.string :address_line2
      t.string :address_postal_code
      t.string :address_state

      t.check_constraint "(stripe_id IS NULL AND (#{required_stub_fields_not_null})) "\
        "OR (stripe_id IS NOT NULL AND (#{all_stub_fields_null}))", name: "stripe_id_or_params"

      t.timestamps
    end
  end
end
