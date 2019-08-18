# frozen_string_literal: true

class RenameSubtypeToCategory < ActiveRecord::Migration[5.1]
  def change
    rename_column :meal_types, :subtype, :category
  end
end
