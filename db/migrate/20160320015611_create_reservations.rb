class CreateReservations < ActiveRecord::Migration[4.2]
  def change
    create_table :reservations do |t|
      t.string :name, limit: 24, null: false
      t.references :resource, null: false, index: true
      t.foreign_key :resources
      t.references :user, null: false, index: true
      t.foreign_key :users
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :kind

      t.timestamps null: false
    end
  end
end
