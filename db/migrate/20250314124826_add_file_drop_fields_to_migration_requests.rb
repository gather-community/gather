# frozen_string_literal: true

class AddFileDropFieldsToMigrationRequests < ActiveRecord::Migration[7.0]
  def up
    add_column :gdrive_migration_requests, :file_drop_drive_id, :string, limit: 128
    add_column :gdrive_migration_requests, :file_drop_drive_name, :string, limit: 128
  end

  def down
    remove_column :gdrive_migration_requests, :file_drop_drive_id
    remove_column :gdrive_migration_requests, :file_drop_drive_name
  end
end
