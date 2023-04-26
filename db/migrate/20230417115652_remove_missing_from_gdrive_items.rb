# frozen_string_literal: true

class RemoveMissingFromGDriveItems < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_items, :missing, :boolean, default: false, null: false
  end
end
