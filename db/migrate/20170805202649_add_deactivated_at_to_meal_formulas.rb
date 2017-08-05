class AddDeactivatedAtToMealFormulas < ActiveRecord::Migration
  def change
    add_column :meal_formulas, :deactivated_at, :datetime
    add_index :meal_formulas, :deactivated_at
  end
end
