# frozen_string_literal: true

module GDrive
  module Migration
    # Scans for all files in the source drive folder.
    class FullScanJob < SourceScanJob
      protected

      def skip_check_for_already_mapped_folders?
        true
      end

      def before_scan_start
        # We save the start page token now so that we can look back through any changes that we miss
        # during the scan operation.
        with_lock(**SCAN_STATUS_LOCK) do
          return if operation.reload.start_page_token.present?
          WebhookRegistrar.setup(operation, wrapper)
        end
      end

      def after_scan_complete
        # We can register for this now since we are finished scanning.
        # We saved the start page token earlier so that we will get any changes
        # we missed during scanning.
        # A rescan finds the channel from the first scan still open, and Google refuses a second
        # channel with the same ID, so we stop it first. The channel ID is set at setup, before
        # any channel exists, so the resource ID is what tells us one was registered.
        WebhookRegistrar.stop(operation, wrapper) if operation.webhook_resource_id.present?
        WebhookRegistrar.register(operation, wrapper)

        # If main scan job is finishing, we should run a change scan because changes
        # may have been piling up (and we ignore them during the main scan)
        ChangesScanJob.enqueue(operation)
      end
    end
  end
end
