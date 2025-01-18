# frozen_string_literal: true

module GDrive
  module Migration
    class WebhookRegistrar
      def self.setup(operation, wrapper)
        operation.log(:info, "Getting start_page_token")
        start_page_token = wrapper.get_changes_start_page_token
        operation.update!(
          # We can setup the channel ID and the secret now too
          # as they are just random tokens and won't change.
          webhook_channel_id: SecureRandom.uuid,
          webhook_secret: SecureRandom.hex,
          start_page_token: start_page_token.start_page_token
        )
      end

      def self.register(operation, wrapper)
        operation.log(:info, "Registering webhook")
        webhook_url_settings = Settings.gdrive&.migration&.changes_webhook_url
        url = Rails.application.routes.url_helpers.gdrive_migration_changes_webhook_url(
          host: webhook_url_settings&.host || Settings.url.host,
          port: webhook_url_settings&.port || Settings.url.port,
          protocol: "https",
          community_id: operation.community_id
        )
        expiration = Time.current + 7.days
        channel = wrapper.watch_change(operation.start_page_token,
          Google::Apis::DriveV3::Channel.new(
            id: operation.webhook_channel_id,
            token: operation.webhook_secret,
            address: url,
            type: "web_hook",
            expiration: expiration.to_i * 1000
          ),
          include_items_from_all_drives: false,
          include_corpus_removals: true,
          include_removed: true,
          spaces: "drive")

        operation.update!(
          webhook_resource_id: channel.resource_id,
          webhook_expires_at: expiration
        )
      end

      def self.stop(operation, wrapper)
        wrapper.stop_channel(Google::Apis::DriveV3::Channel.new(
          id: operation.webhook_channel_id,
          resource_id: operation.webhook_resource_id
        ))
      rescue Google::Apis::ClientError => error
        operation.log(:error, "Client error stopping channel, swallowing", message: error.to_s)
      end
    end
  end
end
