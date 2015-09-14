class ChangeOldIdToInteger < ActiveRecord::Migration
  def change
    change_column :households, :old_id, :integer
  end
end
