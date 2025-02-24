class CreateMealRestrictions < ActiveRecord::Migration[7.0]
  def change
    create_table :meal_restrictions do |t|
      t.string :contains, null: false, limit: 64
      t.string :absence, null: false, limit: 64
      t.references :cluster, foreign_key: true, index: true, null: false
      t.datetime :deactivated_at

      t.references :community, null: false, index: true, foreign_key: true

      t.timestamps
    end
  end
end
