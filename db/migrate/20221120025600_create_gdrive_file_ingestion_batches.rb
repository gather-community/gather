class CreateGDriveFileIngestionBatches < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_file_ingestion_batches do |t|
      t.references :cluster, foreign_key: true, null: false
      t.references :gdrive_config, foreign_key: true, null: false
      t.jsonb :picked, null: false
      t.string :status, null: false, default: "new"

      t.timestamps
    end
  end
end
