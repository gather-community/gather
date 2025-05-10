# frozen_string_literal: true

class MakeMigrationOperationIndexUnique < ActiveRecord::Migration[7.0]
  def change
    remove_index :gdrive_migration_operations, [:community_id]
    add_index :gdrive_migration_operations, [:community_id], unique: true
  end
end
