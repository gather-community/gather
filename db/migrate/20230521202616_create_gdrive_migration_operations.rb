# frozen_string_literal: true

class CreateGDriveMigrationOperations < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_migration_operations do |t|
      t.references :config, foreign_key: {to_table: :gdrive_configs}, null: false, index: true
      t.string :src_folder_id, limit: 255
      t.string :dest_folder_id, limit: 255

      t.timestamps
    end
  end
end
