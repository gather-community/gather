# frozen_string_literal: true

class AddNoAllergensToMeals < ActiveRecord::Migration[5.1]
  def up
    add_column :meals, :no_allergens, :boolean, default: false
    execute(%(UPDATE meals SET no_allergens = (allergens LIKE '%"none"%')))
    change_column_null :meals, :no_allergens, false
  end
end
