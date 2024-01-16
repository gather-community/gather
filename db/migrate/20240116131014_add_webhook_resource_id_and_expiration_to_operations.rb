# frozen_string_literal: true

class AddWebhookResourceIdAndExpirationToOperations < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_operations, :webhook_resource_id, :string
    add_column :gdrive_migration_operations, :webhook_expires_at, :datetime
  end
end
