class CreatePeopleGuardianships < ActiveRecord::Migration
  def change
    create_table :people_guardianships do |t|
      t.integer :child_id
      t.integer :guardian_id

      t.timestamps null: false
    end
    add_index :people_guardianships, :child_id
    add_index :people_guardianships, :guardian_id
  end
end
