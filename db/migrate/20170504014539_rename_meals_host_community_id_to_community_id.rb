class RenameMealsHostCommunityIdToCommunityId < ActiveRecord::Migration
  def change
    rename_column :meals, :host_community_id, :community_id
  end
end
