class CreateLocations < ActiveRecord::Migration
  def change
    create_table :locations do |t|
      t.string :name, null: false
      t.string :abbrv, null: false, limit: 16

      t.timestamps null: false
    end
  end
end
