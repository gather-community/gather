# frozen_string_literal: true

class AddParentIdToGDriveMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_files, :parent_id, :string, null: false
  end
end
