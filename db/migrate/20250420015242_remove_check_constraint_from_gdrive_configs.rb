# frozen_string_literal: true

class RemoveCheckConstraintFromGDriveConfigs < ActiveRecord::Migration[7.0]
  def change
    remove_check_constraint :gdrive_configs, "(type = 'GDrive::MainConfig') = (org_user_id IS NOT NULL)",
      name: :org_user_id_non_null_if_main
  end
end
