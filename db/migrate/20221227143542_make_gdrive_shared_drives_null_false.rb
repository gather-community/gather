class MakeGDriveSharedDrivesNullFalse < ActiveRecord::Migration[7.0]
  def change
    change_column_null :gdrive_shared_drives, :name, false
  end
end
