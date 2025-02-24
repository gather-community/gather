# frozen_string_literal: true

class AdjustGDriveConfigNullConstraints < ActiveRecord::Migration[7.0]
  def change
    change_column_null :gdrive_configs, :api_key, true
    change_column_null :gdrive_configs, :client_id, true
    change_column_null :gdrive_configs, :client_secret, true
    change_column_null :gdrive_configs, :org_user_id, true

    add_check_constraint :gdrive_configs, "(type = 'GDrive::MainConfig') = (api_key IS NOT NULL)",
                         name: :api_key_non_null_if_main
    add_check_constraint :gdrive_configs, "(type = 'GDrive::MainConfig') = (client_id IS NOT NULL)",
                         name: :client_id_non_null_if_main
    add_check_constraint :gdrive_configs, "(type = 'GDrive::MainConfig') = (client_secret IS NOT NULL)",
                         name: :client_secret_non_null_if_main
    add_check_constraint :gdrive_configs, "(type = 'GDrive::MainConfig') = (org_user_id IS NOT NULL)",
                         name: :org_user_id_non_null_if_main
  end
end
