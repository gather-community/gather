# frozen_string_literal: true

class AddExpiredAtToGDriveMigrationRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :gdrive_migration_requests, :expired_at, :datetime
  end
end
