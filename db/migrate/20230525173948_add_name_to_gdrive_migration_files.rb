# frozen_string_literal: true

class AddNameToGDriveMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_files, :name, :text, null: false, limit: 32_767
  end
end
