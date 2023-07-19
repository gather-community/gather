# frozen_string_literal: true

class AddClusterIdToGDriveMigrationOperations < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_operations, :cluster_id, :integer, null: false, index: true
  end
end
