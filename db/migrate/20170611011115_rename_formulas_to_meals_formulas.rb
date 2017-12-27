class RenameFormulasToMealsFormulas < ActiveRecord::Migration[4.2]
  def change
    rename_table :formulas, :meals_formulas
  end
end
