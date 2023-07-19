# frozen_string_literal: true

class RemoveFolderIdFromGDriveConfigs < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_configs, :folder_id, :string
  end
end
