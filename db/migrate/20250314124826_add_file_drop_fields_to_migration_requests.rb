# frozen_string_literal: true

class AddFileDropFieldsToMigrationRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_requests, :file_drop_drive_id, :string, limit: 128
    add_column :gdrive_migration_requests, :file_drop_drive_name, :string, limit: 128

    execute("UPDATE gdrive_migration_requests SET file_drop_drive_id = '', file_drop_drive_name = ''")

    change_column_null :gdrive_migration_requests, :file_drop_drive_id, false
    change_column_null :gdrive_migration_requests, :file_drop_drive_name, false
  end
end
