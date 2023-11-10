# frozen_string_literal: true

class DropGDriveFileIngestionBatches < ActiveRecord::Migration[7.0]
  def up
    drop_table :gdrive_file_ingestion_batches
  end
end
