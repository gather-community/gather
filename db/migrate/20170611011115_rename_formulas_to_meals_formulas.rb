class RenameFormulasToMealsFormulas < ActiveRecord::Migration
  def change
    rename_table :formulas, :meals_formulas
  end
end
