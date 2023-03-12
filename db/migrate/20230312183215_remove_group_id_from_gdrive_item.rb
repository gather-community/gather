# frozen_string_literal: true

class RemoveGroupIdFromGDriveItem < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_items, :group_id, :integer
  end
end
