class AddMissingToGDriveItems < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_items, :missing, :boolean, null: false, default: true, index: true
  end
end
