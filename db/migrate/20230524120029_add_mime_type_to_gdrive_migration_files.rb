# frozen_string_literal: true

class AddMimeTypeToGDriveMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_files, :mime_type, :string, null: false, limit: 255
  end
end
