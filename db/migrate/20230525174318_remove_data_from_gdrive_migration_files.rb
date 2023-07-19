# frozen_string_literal: true

class RemoveDataFromGDriveMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_migration_files, :data, :jsonb
  end
end
