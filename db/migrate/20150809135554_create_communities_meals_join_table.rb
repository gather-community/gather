class CreateCommunitiesMealsJoinTable < ActiveRecord::Migration
  def change
    remove_column :meals, :community_id

    create_table :invitations do |t|
      t.references :community, index: true, null: false
      t.references :meal, index: true, null: false
      t.foreign_key :communities
      t.foreign_key :meals
    end
  end
end
