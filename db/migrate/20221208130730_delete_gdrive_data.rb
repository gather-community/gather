class DeleteGDriveData < ActiveRecord::Migration[7.0]
  def up
    execute("DELETE FROM gdrive_unowned_files")
    execute("DELETE FROM gdrive_file_ingestion_batches")
    execute("DELETE FROM gdrive_configs")
  end
end
