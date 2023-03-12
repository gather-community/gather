class CreateGDriveItemGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_item_groups do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :item, foreign_key: {to_table: :gdrive_items}, null: false, index: true
      t.references :group, foreign_key: {to_table: :groups}, null: false, index: true
      t.string :access_level, null: false

      t.check_constraint "access_level IN ('fileOrganizer', 'writer', 'commenter', 'reader')"
      t.index %i[item_id group_id], unique: true
      t.timestamps
    end
  end
end
