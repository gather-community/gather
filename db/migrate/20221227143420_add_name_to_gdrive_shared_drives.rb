class AddNameToGDriveSharedDrives < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_shared_drives, :name, :string
  end
end
