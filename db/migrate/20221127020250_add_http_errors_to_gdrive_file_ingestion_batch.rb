class AddHttpErrorsToGDriveFileIngestionBatch < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_file_ingestion_batches, :http_errors, :jsonb
  end
end
