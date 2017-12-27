class RenameOrRemoveOldGrotFields < ActiveRecord::Migration[4.2]
  def up
    rename_column :households, :old_name, :alternate_id
    remove_column :households, :old_id
  end
end
