class CreateGDriveUnownedFiles < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_unowned_files do |t|
      t.references :cluster, foreign_key: true, null: false
      t.references :gdrive_config, foreign_key: true, null: false
      t.string :external_id, null: false
      t.string :owner, null: false
      t.jsonb :data, null: false

      t.timestamps
      t.index %i[gdrive_config_id external_id], unique: true
    end
  end
end
