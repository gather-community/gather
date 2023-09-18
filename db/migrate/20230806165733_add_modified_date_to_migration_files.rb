# frozen_string_literal: true

class AddModifiedDateToMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_files, :modified_at, :datetime
    reversible { |dir| dir.up { execute("UPDATE gdrive_migration_files SET modified_at = NOW()") } }
    change_column_null :gdrive_migration_files, :modified_at, false
  end
end
