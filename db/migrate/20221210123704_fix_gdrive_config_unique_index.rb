class FixGDriveConfigUniqueIndex < ActiveRecord::Migration[7.0]
  def change
    remove_index :gdrive_configs, [:community_id], unique: true
    add_index :gdrive_configs, %i[community_id type], unique: true
  end
end
