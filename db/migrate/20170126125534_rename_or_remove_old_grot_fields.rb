class RenameOrRemoveOldGrotFields < ActiveRecord::Migration
  def up
    rename_column :households, :old_name, :alternate_id
    remove_column :households, :old_id
  end
end
