# frozen_string_literal: true

class RemoveTypeFromGDriveConfigs < ActiveRecord::Migration[7.0]
  def change

    reversible do |dir|
      dir.up do
        execute("DELETE FROM gdrive_tokens WHERE gdrive_config_id IN (SELECT id FROM gdrive_configs WHERE type = 'GDrive::MigrationConfig')")
        execute("DELETE FROM gdrive_configs WHERE type = 'GDrive::MigrationConfig'")
      end
    end
    remove_column :gdrive_configs, :type, :string
  end
end
