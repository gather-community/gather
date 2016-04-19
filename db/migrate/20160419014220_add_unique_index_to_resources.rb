class AddUniqueIndexToResources < ActiveRecord::Migration
  def change
    add_index :resources, [:community_id, :name], unique: true
  end
end
