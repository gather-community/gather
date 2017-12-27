class FixMealTitleNull < ActiveRecord::Migration[4.2]
  def change
    change_column_null :meals, :title, true
  end
end
