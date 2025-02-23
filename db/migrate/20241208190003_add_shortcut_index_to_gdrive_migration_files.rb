# frozen_string_literal: true

class AddShortcutIndexToGDriveMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    add_index :gdrive_migration_files, %i[operation_id shortcut_target_id], name: :gdrive_files_on_shortcut
  end
end
