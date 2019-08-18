# frozen_string_literal: true

class CreateMealsSignupParts < ActiveRecord::Migration[5.1]
  def change
    create_table :meal_signup_parts do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :signup, index: true, null: false, foreign_key: {to_table: :meal_signups}
      t.references :type, index: true, null: false, foreign_key: {to_table: :meal_types}
      t.integer :count, null: false

      t.timestamps
      t.index %w[type_id signup_id], unique: true
    end
  end
end
