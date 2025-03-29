# frozen_string_literal: true

class AddFileDropDriveIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :gdrive_migration_requests, :file_drop_drive_id, unique: true
  end
end
