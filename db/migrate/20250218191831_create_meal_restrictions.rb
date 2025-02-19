class CreateMealRestrictions < ActiveRecord::Migration[7.0]
  def change
    create_table :meal_restrictions do |t|
      t.string :contains, null: false
      t.string :absence, null: false
      t.boolean :enabled, default: true, null: false
      t.references :community, null: false, index: true
      t.foreign_key :communities

      t.timestamps
    end
  end
end
