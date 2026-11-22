# frozen_string_literal: true

module GDrive
  # Runs nightly. For every community connected to Google Drive, it syncs each linked item's
  # permissions again, then checks Google against what Gather expects and reports anything still wrong
  # to Sentry.
  #
  # The syncs triggered by changes in Gather can fail or be dropped, e.g. when Google refuses a change.
  # Without this job, a removal that failed once would stay undone, and the person would keep access.
  class PermissionReconciliationJob < BaseJob
    # Reported once per item whose permissions still differ from Gather after the sync.
    class DiscrepancyError < StandardError
    end

    # Enough to act on in Sentry without making the event huge.
    MAX_REPORTED_DISCREPANCIES = 50

    def perform
      configs = ActsAsTenant.without_tenant { Config.includes(:cluster).to_a }
      configs.each do |config|
        with_cluster(config.cluster) { reconcile(config) }
      end
    end

    private

    def reconcile(config)
      wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id)
      unless wrapper.has_credentials?
        Rails.logger.info("Skipping reconciliation, community not connected to Google",
          community_id: config.community_id)
        return
      end

      config.items.accessible.order(:id).each do |item|
        sync_item(config, item)
        audit_item(config, wrapper, item) if Item.exists?(item.id)
      end
    rescue Google::Apis::AuthorizationError, Signet::AuthorizationError => error
      # The connection needs an admin to sign in again. Every item would fail the same way.
      report(error, config)
    end

    def sync_item(config, item)
      # Called directly so it runs now, in order, and its errors come back to us.
      ItemPermissionSyncJob.new.perform(cluster_id: config.cluster_id, community_id: config.community_id,
        item_id: item.id, refresh_synced_permissions: true)
    rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
      raise
    rescue => error
      # The audit below still reports whatever this left wrong, so we carry on.
      report(error, config, item_id: item.id)
    end

    def audit_item(config, wrapper, item)
      discrepancies = PermissionAudit.new(wrapper: wrapper, item: item.reload).discrepancies
      return if discrepancies.empty?

      Rails.logger.error("Drive permissions differ from Gather after reconciliation",
        community_id: config.community_id, item_id: item.id, count: discrepancies.size)
      error = DiscrepancyError.new("Google Drive permissions still differ from Gather after reconciliation")
      report(error, config, item_id: item.id, item_external_id: item.external_id,
        discrepancy_count: discrepancies.size,
        discrepancies: discrepancies.first(MAX_REPORTED_DISCREPANCIES).map(&:to_h))
    rescue Google::Apis::ClientError => error
      report(error, config, item_id: item.id)
    end

    def report(error, config, **data)
      Gather::ErrorReporter.instance.report(error,
        data: {job: self.class.name, community_id: config.community_id, **data})
    end
  end
end
