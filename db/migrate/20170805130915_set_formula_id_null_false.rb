# frozen_string_literal: true

class SetFormulaIdNullFalse < ActiveRecord::Migration[4.2]
  def up
    change_column_null :meals, :formula_id, false
  end
end
