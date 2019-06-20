# frozen_string_literal: true

class CreateMealTypes < ActiveRecord::Migration[5.1]
  def change
    create_table :meal_types do |t|
      t.references :community, null: false, index: true, foreign_key: true
      t.references :cluster, null: false, index: true, foreign_key: true
      t.string :name, null: false, limit: 32
      t.boolean :discounted, null: false, default: false
      t.string :subtype, limit: 32

      t.timestamps
    end
  end
end
