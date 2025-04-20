# frozen_string_literal: true

class AddCommunityToMigrationOperations < ActiveRecord::Migration[7.0]
  def up
    add_reference :gdrive_migration_operations, :community, index: true, foreign_key: true
    execute("UPDATE gdrive_migration_operations SET community_id =
      (SELECT community_id FROM gdrive_configs WHERE id = gdrive_migration_operations.config_id)")
  end
end
