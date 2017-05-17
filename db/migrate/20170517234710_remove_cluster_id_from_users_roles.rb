class RemoveClusterIdFromUsersRoles < ActiveRecord::Migration
  def up
    remove_column :users_roles, :cluster_id
  end
end
