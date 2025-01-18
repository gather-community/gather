# frozen_string_literal: true

module GDrive
  module Migration
    class WebhooksController < ApplicationController
      # These are public pages. Authentication comes from the token in the header.
      skip_before_action :authenticate_user!
      skip_before_action :verify_authenticity_token
      skip_after_action :verify_authorized

      prepend_before_action :set_current_community_from_query_string

      # For signed-in pages, we redirect to the appropriate community.
      # Here we should 404 if no community, except for the callback endpoint
      before_action :ensure_community

      def changes
        # By the time this endpoint is being called for a given operation, that operation
        # should already have values for webhook_channel_id, webhook_secret, and start_page_token,
        # since those are created when we set up the webhook channel initially.
        operation = Operation.in_community(current_community)
          .find_by(webhook_channel_id: request.headers["x-goog-channel-id"])

        if operation.nil?
          Rails.logger.error("x-goog-channel-id does not match any operations in this community")
          return render_not_found
        end

        if operation.webhook_secret != request.headers["x-goog-channel-token"]
          operation.log(:error, "x-goog-channel-token does not match the webhook secret")
          return render_not_found
        end

        unless operation.active?
          operation.log(:info, "Operation is inactive, not processing webhook")
        end

        ScanJob.with_lock(operation.id) do
          # No need to start a new scan if there is already one that hasn't started running.
          # Background jobs only get started every few seconds so this should debounce
          # things if a lot of webhook pings are coming in.
          # We do this in a critical section so that we don't have any race conditions.
          if !operation.scans.changes.any?(&:new?)
            ScanJob.enqueue_change_scan_job(operation)
          end
        end
      end

      private

      def ensure_community
        render_not_found unless current_community
      end
    end
  end
end
