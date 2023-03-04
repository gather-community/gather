class RenameGDriveSharedDrivesToGDriveItems < ActiveRecord::Migration[7.0]
  def change
    rename_table :gdrive_shared_drives, :gdrive_items
  end
end
