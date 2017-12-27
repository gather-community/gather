class CreateFormulas < ActiveRecord::Migration[4.2]
  def change
    create_table :formulas do |t|
      t.references :community, foreign_key: true, index: true, null: false
      t.date :effective_on, null: false, index: true

      t.decimal :senior_meat, precision: 5, scale: 3
      t.decimal :adult_meat, precision: 5, scale: 3
      t.decimal :teen_meat, precision: 5, scale: 3
      t.decimal :big_kid_meat, precision: 5, scale: 3
      t.decimal :little_kid_meat, precision: 5, scale: 3
      t.decimal :senior_veg, precision: 5, scale: 3
      t.decimal :adult_veg, precision: 5, scale: 3
      t.decimal :teen_veg, precision: 5, scale: 3
      t.decimal :big_kid_veg, precision: 5, scale: 3
      t.decimal :little_kid_veg, precision: 5, scale: 3

      t.decimal :pantry_fee, precision: 5, scale: 3
      t.string :meal_calc_type, null: false
      t.string :pantry_calc_type
    end
  end
end
