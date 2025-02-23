# frozen_string_literal: true

class ChangeScanTaskToHangOffScan < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_migration_scan_tasks, :operation_id, :bigint
    add_reference :gdrive_migration_scan_tasks, :scan, null: false, index: true,
                                                       foreign_key: {to_table: :gdrive_migration_scans}
  end
end
