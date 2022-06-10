# frozen_string_literal: true

class RemoveOldGDriveTables < ActiveRecord::Migration[6.0]
  def up
    drop_table(:gdrive_configs, if_exists: true)
    drop_table(:gdrive_stray_files, if_exists: true)
  end
end
