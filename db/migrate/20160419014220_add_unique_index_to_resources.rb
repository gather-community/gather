class AddUniqueIndexToResources < ActiveRecord::Migration[4.2]
  def change
    add_index :resources, [:community_id, :name], unique: true
  end
end
