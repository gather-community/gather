class RemoveEffectiveOnFromFormulas < ActiveRecord::Migration
  def change
    add_column :meal_formulas, :created_at, :datetime
    add_column :meal_formulas, :updated_at, :datetime
    execute("UPDATE meal_formulas SET
      created_at = effective_on::timestamp, updated_at = effective_on::timestamp")
    remove_column :meal_formulas, :effective_on, :date
    change_column_null :meal_formulas, :created_at, false
    change_column_null :meal_formulas, :updated_at, false
  end
end
