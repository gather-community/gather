# frozen_string_literal: true

class SetNullFalseOnFolderMapDestIds < ActiveRecord::Migration[7.0]
  def change
    change_column_null :gdrive_migration_folder_maps, :dest_id, false
    change_column_null :gdrive_migration_folder_maps, :dest_parent_id, false
  end
end
