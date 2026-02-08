# frozen_string_literal: true

class UpdateRequestStatuses < ActiveRecord::Migration[7.0]
  def change
    remove_check_constraint :gdrive_migration_requests, "status IN ('new', 'in_progress', 'done', 'opted_out')",
      name: :status_enum
    add_check_constraint :gdrive_migration_requests, "status IN ('new', 'opened', 'opted_out')",
      name: :status_enum
  end
end
