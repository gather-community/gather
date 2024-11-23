# frozen_string_literal: true

class AddShortcutFieldsToGDriveMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_files, :shortcut_target_id, :string, limit: 128
    add_column :gdrive_migration_files, :shortcut_target_mime_type, :string, limit: 128
  end
end
