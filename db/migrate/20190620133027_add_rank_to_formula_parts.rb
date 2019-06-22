# frozen_string_literal: true

class AddRankToFormulaParts < ActiveRecord::Migration[5.1]
  def change
    add_column :meal_formula_parts, :rank, :integer, null: false
  end
end
