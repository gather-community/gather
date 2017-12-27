class CreateAssignments < ActiveRecord::Migration[4.2]
  def change
    create_table :assignments do |t|
      t.references :meal, index: true, null: false
      t.references :user, index: true, null: false
      t.foreign_key :meals
      t.foreign_key :users
      t.string :role, null: false, index: true

      t.timestamps null: false
    end
  end
end
