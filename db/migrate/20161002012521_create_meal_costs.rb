class CreateMealCosts < ActiveRecord::Migration[4.2]
  def change
    create_table :meal_costs do |t|
      t.references :meal, index: true, foreign_key: true, null: false

      t.decimal :adult_meat, precision: 10, scale: 2
      t.decimal :adult_veg, precision: 10, scale: 2
      t.decimal :big_kid_meat, precision: 10, scale: 2
      t.decimal :big_kid_veg, precision: 10, scale: 2
      t.decimal :little_kid_meat, precision: 10, scale: 2
      t.decimal :little_kid_veg, precision: 10, scale: 2
      t.decimal :senior_meat, precision: 10, scale: 2
      t.decimal :senior_veg, precision: 10, scale: 2
      t.decimal :teen_meat, precision: 10, scale: 2
      t.decimal :teen_veg, precision: 10, scale: 2

      t.string :meal_calc_type
      t.string :pantry_calc_type
      t.decimal :pantry_fee, precision: 10, scale: 2

      t.decimal :ingredient_cost, precision: 10, scale: 2
      t.decimal :pantry_cost, precision: 10, scale: 2

      t.timestamps null: false
    end
  end
end
