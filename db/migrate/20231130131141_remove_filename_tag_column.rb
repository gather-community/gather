# frozen_string_literal: true

class RemoveFilenameTagColumn < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_migration_operations, :filename_tag, :string, limit: 8, null: false
  end
end
