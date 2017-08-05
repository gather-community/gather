class SetFormulaIdNullFalse < ActiveRecord::Migration
  def up
    change_column_null :meals, :formula_id, false
  end
end
