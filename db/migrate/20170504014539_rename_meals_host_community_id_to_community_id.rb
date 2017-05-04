class RenameMealsHostCommunityIdToCommunityId < ActiveRecord::Migration
  def change
    rename_column :meals, :community_id, :community_id
  end
end
