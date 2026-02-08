# frozen_string_literal: true

class AddLogDataToScansModel < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_scans, :log_data, :jsonb, null: true
  end
end
