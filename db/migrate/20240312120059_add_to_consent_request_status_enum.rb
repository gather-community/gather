# frozen_string_literal: true

class AddToConsentRequestStatusEnum < ActiveRecord::Migration[7.0]
  def change
    remove_check_constraint :gdrive_migration_consent_requests, "status IN ('new', 'in_progress', 'done', 'opted_out')",
                            name: :status_enum
    add_check_constraint :gdrive_migration_consent_requests, "status IN ('new', 'in_progress', 'done', 'opted_out', 'ingest_failed')",
                         name: :status_enum
  end
end
