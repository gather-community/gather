class CreateSignups < ActiveRecord::Migration[4.2]
  def change
    create_table :signups do |t|
      t.references :meal, null: false, index: true, foreign_key: true
      t.references :household, null: false, index: true, foreign_key: true
      t.integer :adult_meat, null: false, default: 0
      t.integer :adult_veg, null: false, default: 0
      t.integer :teen, null: false, default: 0
      t.integer :big_kid, null: false, default: 0
      t.integer :little_kid, null: false, default: 0
      t.text :comments

      t.timestamps null: false
    end
  end
end
