# frozen_string_literal: true

class CreateGDriveTokens < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_tokens do |t|
      t.references :cluster, foreign_key: true, null: false
      t.references :gdrive_config, foreign_key: true, null: false
      t.string :google_user_id, null: false
      t.text :data, null: false, limit: 2048

      t.timestamps
    end
  end
end
