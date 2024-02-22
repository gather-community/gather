# frozen_string_literal: true

class RemoveOperationStatus < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_migration_operations, :status, :string, default: "new", null: false
  end
end
