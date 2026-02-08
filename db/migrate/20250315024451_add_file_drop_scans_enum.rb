# frozen_string_literal: true

class AddFileDropScansEnum < ActiveRecord::Migration[7.0]
  def change
    remove_check_constraint :gdrive_migration_scans, "scope IN ('full', 'changes')",
      name: :scope_enum
    add_check_constraint :gdrive_migration_scans, "scope IN ('full', 'changes', 'file_drop')",
      name: :scope_enum
  end
end
