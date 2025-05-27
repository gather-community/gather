# frozen_string_literal: true

module GDrive
  module Migration
    # For any active migration operations, update webhooks.
    class WebhookRefreshJob < BaseJob
      def perform
        ActsAsTenant.without_tenant do
          GDrive::Migration::Operation.active.where("webhook_expires_at < ?", Time.current + 2.days).find_each do |operation|
            ActsAsTenant.with_tenant(operation.cluster) do
              refresh_webhook(operation)
            end
          end
        end
      end

      private

      def refresh_webhook(operation)
        # We build the wrapper using the main config because the webhook uses the main config user.
        config = Config.find_by(community: operation.community)
        wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id)

        WebhookRegistrar.stop(operation, wrapper)
        WebhookRegistrar.register(operation, wrapper)
      end
    end
  end
end
