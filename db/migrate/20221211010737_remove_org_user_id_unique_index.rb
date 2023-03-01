class RemoveOrgUserIdUniqueIndex < ActiveRecord::Migration[7.0]
  def change
    remove_index :gdrive_configs, :org_user_id, unique: true
    add_index :gdrive_configs, :org_user_id
  end
end
