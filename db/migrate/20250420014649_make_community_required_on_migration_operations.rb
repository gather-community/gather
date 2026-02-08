# frozen_string_literal: true

class MakeCommunityRequiredOnMigrationOperations < ActiveRecord::Migration[7.0]
  def change
    change_column_null :gdrive_migration_operations, :community_id, false
  end
end
