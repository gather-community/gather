# frozen_string_literal: true

class RelaxNullConstraintOnScanTasks < ActiveRecord::Migration[7.0]
  def change
    change_column_null :gdrive_migration_scan_tasks, :folder_id, true
  end
end
