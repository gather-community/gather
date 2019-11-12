# frozen_string_literal: true

class RemoveClusterIdFromUsersRoles < ActiveRecord::Migration[4.2]
  def up
    remove_column :users_roles, :cluster_id
  end
end
