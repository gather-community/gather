# frozen_string_literal: true

class CreateMealsCostParts < ActiveRecord::Migration[5.1]
  def change
    create_table :meal_cost_parts do |t|
      t.references :cluster, index: true, null: false, foreign_key: true
      t.references :type, index: true, null: false, foreign_key: {to_table: :meal_types}
      t.references :cost, index: true, null: false, foreign_key: {to_table: :meal_costs}
      t.decimal :value, precision: 10, scale: 2

      t.timestamps
      t.index %w[type_id cost_id], unique: true
    end
  end
end
