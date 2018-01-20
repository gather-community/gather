class CreatePeopleGroups < ActiveRecord::Migration[5.1]
  def change
    create_table :people_groups do |t|
      t.string :name, null: false
      t.integer :community_id, null: false
      t.integer :cluster_id, null: false

      t.timestamps
    end

    add_index :people_groups, :community_id
    add_index :people_groups, :cluster_id
    add_index :people_groups, [:cluster_id, :community_id, :name], unique: true
  end
end
