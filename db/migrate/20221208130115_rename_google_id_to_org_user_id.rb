class RenameGoogleIdToOrgUserId < ActiveRecord::Migration[7.0]
  def change
    rename_column :gdrive_configs, :google_id, :org_user_id
  end
end
