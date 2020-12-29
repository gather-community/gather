# frozen_string_literal: true

class CreateBillingTemplates < ActiveRecord::Migration[6.0]
  def change
    create_table :billing_templates do |t|
      t.references :cluster, index: true, foreign_key: true, null: false
      t.references :community, index: true, foreign_key: true, null: false
      t.string :description, null: false, limit: 255
      t.string :code, null: false, limit: 16
      t.decimal :amount, null: false, precision: 10, scale: 2

      t.timestamps
    end
  end
end
