class RemoveDiscountFromMeals < ActiveRecord::Migration[4.2]
  def up
    remove_column :meals, :discount
  end
end
