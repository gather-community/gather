class RemoveDiscountFromMeals < ActiveRecord::Migration
  def up
    remove_column :meals, :discount
  end
end
