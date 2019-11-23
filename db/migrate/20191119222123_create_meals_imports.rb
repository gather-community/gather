# frozen_string_literal: true

class CreateMealsImports < ActiveRecord::Migration[6.0]
  def change
    create_table :meal_imports do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :community, foreign_key: true, index: true, null: false
      t.references :user, foreign_key: true, index: true, null: false
      t.jsonb :errors_by_row
      t.string :status, null: false, default: "queued"

      t.timestamps
    end
  end
end
