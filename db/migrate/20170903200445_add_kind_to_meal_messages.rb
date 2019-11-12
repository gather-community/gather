# frozen_string_literal: true

class AddKindToMealMessages < ActiveRecord::Migration[4.2]
  def change
    add_column :meal_messages, :kind, :string, null: false, default: "normal"
  end
end
