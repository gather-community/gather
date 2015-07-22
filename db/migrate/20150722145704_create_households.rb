class CreateHouseholds < ActiveRecord::Migration
  def change
    create_table :households do |t|
      t.string :name, null: false
      t.integer :unit_num, null: false
      t.references :community, index: true, null: false

      t.timestamps null: false
    end
  end
end
