# frozen_string_literal: true

class AddUniqueIndexForGDriveMigrationRequests < ActiveRecord::Migration[7.0]
  def change
    add_index :gdrive_migration_requests, [:operation_id, :google_email], unique: true, name: :index_migration_requests_on_operation_id_and_google_email
  end
end
