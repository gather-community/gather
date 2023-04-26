class AddKindToGDriveItems < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_items, :kind, :string, index: true
    reversible { |dir| dir.up { execute("UPDATE gdrive_items SET kind = 'drive'") } }
    change_column_null :gdrive_items, :kind, false
    add_check_constraint :gdrive_items, "kind IN ('drive', 'folder', 'file')", name: :kind_enum
  end
end
