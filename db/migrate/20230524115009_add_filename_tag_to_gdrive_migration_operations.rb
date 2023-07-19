# frozen_string_literal: true

class AddFilenameTagToGDriveMigrationOperations < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_operations, :filename_tag, :string, null: false, limit: 8
  end
end
