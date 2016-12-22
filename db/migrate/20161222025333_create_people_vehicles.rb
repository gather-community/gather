class CreatePeopleVehicles < ActiveRecord::Migration
  def change
    create_table :people_vehicles do |t|
      t.references :household, index: true, foreign_key: true
      t.string :make
      t.string :model
      t.string :color

      t.timestamps null: false
    end
  end
end
