# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :subscriptions do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :community, foreign_key: true, index: {unique: true}, null: false
      t.string :stripe_id, null: false

      t.timestamps
    end
  end
end
