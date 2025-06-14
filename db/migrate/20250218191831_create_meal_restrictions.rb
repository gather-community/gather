# frozen_string_literal: true

class CreateMealRestrictions < ActiveRecord::Migration[7.0]
  def change
    create_table :meal_restrictions do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :community, foreign_key: true, index: true, null: false
      t.string :contains, null: false
      t.string :absence, null: false
      t.boolean :deactivated, default: false, null: false

      t.timestamps
    end
  end
end
