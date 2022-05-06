# frozen_string_literal: true

class CreateGDriveConfigs < ActiveRecord::Migration[6.0]
  def change
    create_table :gdrive_configs do |t|
      t.references :cluster, foreign_key: true, null: false
      t.references :community, foreign_key: true, null: false, index: {unique: true}
      t.string :google_id, limit: 255, null: false, index: {unique: true}
      t.string :token, limit: 255
      t.timestamps
    end
  end
end
