# frozen_string_literal: true

class AddTypeToGDriveConfigs < ActiveRecord::Migration[7.0]
  def up
    add_column :gdrive_configs, :type, :string
    execute("UPDATE gdrive_configs SET type = 'GDrive::MigrationConfig'")
    change_column_null :gdrive_configs, :type, false
  end

  def down
    remove_column :gdrive_configs, :type
  end
end
