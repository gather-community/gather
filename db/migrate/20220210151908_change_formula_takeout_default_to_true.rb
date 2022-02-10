# frozen_string_literal: true

class ChangeFormulaTakeoutDefaultToTrue < ActiveRecord::Migration[6.0]
  def change
    change_column_default :meal_formulas, :takeout, true
  end
end
