class AddAppCredsToGDriveConfigs < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_configs, :client_id, :string, null: false
    add_column :gdrive_configs, :client_secret, :string, null: false
    add_column :gdrive_configs, :api_key, :string, null: false
  end
end
