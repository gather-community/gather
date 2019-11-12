# frozen_string_literal: true

class CreateMealsMessages < ActiveRecord::Migration[4.2]
  def change
    create_table :meals_messages do |t|
      t.integer :sender_id, null: false
      t.integer :meal_id, null: false
      t.string :recipients, null: false
      t.text :body, null: false
      t.integer :cluster_id, null: false

      t.timestamps null: false
    end
  end
end
