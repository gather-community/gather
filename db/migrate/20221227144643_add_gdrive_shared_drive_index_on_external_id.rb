class AddGDriveSharedDriveIndexOnExternalId < ActiveRecord::Migration[7.0]
  def change
    add_index :gdrive_shared_drives, :external_id, unique: true
  end
end
