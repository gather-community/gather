class FixMealTitleNull < ActiveRecord::Migration
  def change
    change_column_null :meals, :title, true
  end
end
