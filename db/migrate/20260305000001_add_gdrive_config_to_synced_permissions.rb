# frozen_string_literal: true

class AddGDriveConfigToSyncedPermissions < ActiveRecord::Migration[7.0]
  def up
    add_column :gdrive_synced_permissions, :gdrive_config_id, :bigint

    # Backfill via the item association.
    execute <<~SQL
      UPDATE gdrive_synced_permissions sp
      SET gdrive_config_id = i.gdrive_config_id
      FROM gdrive_items i
      WHERE sp.item_id = i.id
    SQL

    # Delete orphans whose item no longer exists in gdrive_items.
    execute "DELETE FROM gdrive_synced_permissions WHERE gdrive_config_id IS NULL"

    change_column_null :gdrive_synced_permissions, :gdrive_config_id, false
    add_index :gdrive_synced_permissions, :gdrive_config_id
    add_foreign_key :gdrive_synced_permissions, :gdrive_configs
  end

  def down
    remove_foreign_key :gdrive_synced_permissions, :gdrive_configs
    remove_column :gdrive_synced_permissions, :gdrive_config_id
  end
end
