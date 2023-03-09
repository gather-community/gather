class ChangeGDriveItemsActiveToMissing < ActiveRecord::Migration[7.0]
  def change
    rename_column :gdrive_items, :active, :missing
    change_column_default :gdrive_items, :missing, false
  end
end
