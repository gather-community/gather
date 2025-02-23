# frozen_string_literal: true

class AddGDriveCheckConstraints < ActiveRecord::Migration[7.0]
  def change
    add_check_constraint :gdrive_migration_scans, "scope IN ('full', 'changes')",
                         name: :scope_enum
    add_check_constraint :gdrive_migration_scans, "status IN ('new', 'in_progress', 'cancelled', 'complete')",
                         name: :status_enum
    add_check_constraint :gdrive_synced_permissions, "access_level IN ('reader', 'commenter', 'writer', 'fileOrganizer')",
                         name: :access_level_enum
  end
end
