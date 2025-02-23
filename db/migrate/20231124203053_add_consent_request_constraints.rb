# frozen_string_literal: true

class AddConsentRequestConstraints < ActiveRecord::Migration[7.0]
  def change
    change_column_default :gdrive_migration_consent_requests, :status, "new"

    add_check_constraint :gdrive_migration_consent_requests, "status IN ('new', 'in_progress', 'done', 'opted_out')",
                         name: :status_enum

    add_check_constraint :gdrive_migration_consent_requests, "ingest_status IN ('new', 'in_progress', 'done', 'failed')",
                         name: :ingest_status_enum
  end
end
