# frozen_string_literal: true

class CreateGDriveMigrationFolderMaps < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_migration_folder_maps do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :operation, index: true, null: false,
                               foreign_key: {to_table: :gdrive_migration_operations}
      t.string :src_id, null: false
      t.string :src_parent_id, null: false
      t.string :dest_id
      t.string :dest_parent_id
      t.string :name, null: false
      t.index %i[operation_id src_id], unique: true

      t.timestamps
    end
  end
end
