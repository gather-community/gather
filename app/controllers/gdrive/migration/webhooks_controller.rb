# frozen_string_literal: true

module GDrive
  module Migration
    class WebhooksController < ApplicationController
      # These are public pages. Authentication comes from the token in the header.
      skip_before_action :authenticate_user!
      skip_after_action :verify_authorized

      # For signed-in pages, we redirect to the appropriate community.
      # Here we should 404 if no community, except for the callback endpoint
      before_action :ensure_community

      def changes
        # By the time this endpoint is being called for a given operation, that operation
        # should already have values for webhook_channel_id, webhook_secret, and start_page_token,
        # since one of those are created when we set up the webhook channel initially.
        operation = Operation.in_community(current_community)
          .find_by(webhook_channel_id: request.headers["x-goog-channel-id"])

        if operation.nil?
          Rails.logger.error("x-goog-channel-id does not match any operations in this community")
          return render_not_found
        end

        if operation.webhook_secret != request.headers["x-goog-channel-token"]
          Rails.logger.error("x-goog-channel-token does not match the webhook secret", operation_id: operation.id)
          return render_not_found
        end

        scan = operation.scans.create!(scope: "changes")
        scan_task = scan.scan_tasks.create!(page_token: operation.start_page_token)
        ScanJob.perform_later(cluster_id: current_cluster.id, scan_task_id: scan_task.id)
      end

      private

      def ensure_community
        render_not_found unless current_community
      end
    end
  end
end
