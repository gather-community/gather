class AddActiveToGDriveItems < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_items, :active, :boolean, null: false, default: true, index: true
  end
end
