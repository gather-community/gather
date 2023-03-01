class RemoveTokenFromGDriveConfigs < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_configs, :token, :string
  end
end
