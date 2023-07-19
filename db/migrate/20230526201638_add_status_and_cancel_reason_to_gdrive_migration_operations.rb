# frozen_string_literal: true

class AddStatusAndCancelReasonToGDriveMigrationOperations < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_operations, :status, :string, null: false, default: "new"
    add_column :gdrive_migration_operations, :cancel_reason, :string
  end
end
