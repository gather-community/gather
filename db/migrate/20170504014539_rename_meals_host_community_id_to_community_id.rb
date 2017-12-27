class RenameMealsHostCommunityIdToCommunityId < ActiveRecord::Migration[4.2]
  def change
    rename_column :meals, :host_community_id, :community_id
  end
end
