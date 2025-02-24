# frozen_string_literal: true

class FixConstraintsOnGDriveConfigs < ActiveRecord::Migration[7.0]
  def change
    remove_check_constraint :gdrive_configs,
                            "(type::text = 'GDrive::MainConfig'::text) = (api_key IS NOT NULL)", name: "api_key_non_null_if_main"
    remove_check_constraint :gdrive_configs,
                            "(type::text = 'GDrive::MainConfig'::text) = (client_id IS NOT NULL)", name: "client_id_non_null_if_main"
    remove_check_constraint :gdrive_configs,
                            "(type::text = 'GDrive::MainConfig'::text) = (client_secret IS NOT NULL)", name: "client_secret_non_null_if_main"

    reversible do |dir|
      dir.up do
        execute("UPDATE gdrive_configs SET api_key = 'xxx', client_id = 'xxx', client_secret = 'xxx' WHERE type = 'GDrive::MigrationConfig'")
      end
    end

    change_column_null :gdrive_configs, :api_key, false
    change_column_null :gdrive_configs, :client_id, false
    change_column_null :gdrive_configs, :client_secret, false
  end
end
