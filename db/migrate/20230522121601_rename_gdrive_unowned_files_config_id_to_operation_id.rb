# frozen_string_literal: true

class RenameGDriveUnownedFilesConfigIdToOperationId < ActiveRecord::Migration[7.0]
  def change
    rename_column :gdrive_unowned_files, :gdrive_config_id, :operation_id
  end
end
