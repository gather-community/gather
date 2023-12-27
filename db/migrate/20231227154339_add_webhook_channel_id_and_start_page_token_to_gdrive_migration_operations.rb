# frozen_string_literal: true

class AddWebhookChannelIdAndStartPageTokenToGDriveMigrationOperations < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_operations, :webhook_channel_id, :string
    add_column :gdrive_migration_operations, :start_page_token, :string
  end
end
