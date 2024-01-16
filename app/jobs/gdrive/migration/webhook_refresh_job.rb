# frozen_string_literal: true

module GDrive
  module Migration
    # For any active migration operations, update webhooks.
    class WebhookRefreshJob < BaseJob
      def perform
      end
    end
  end
end
