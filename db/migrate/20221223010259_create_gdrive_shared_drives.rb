# frozen_string_literal: true

class CreateGDriveSharedDrives < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_shared_drives do |t|
      t.references :cluster, foreign_key: true, null: false
      t.references :gdrive_config, foreign_key: true, null: false
      t.references :group, foreign_key: true, null: false
      t.string :external_id, limit: 255, null: false

      t.timestamps
    end
  end
end
