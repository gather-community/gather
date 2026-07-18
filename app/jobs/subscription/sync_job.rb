# frozen_string_literal: true

module Subscription
  # Refreshes a single subscription's cached status from Stripe. Enqueued by Stripe webhooks
  # for the affected subscription. Looks the subscription up across tenants, then syncs within
  # its cluster's tenant context.
  class SyncJob < ApplicationJob
    def perform(subscription_id)
      ActsAsTenant.without_tenant do
        sub = Subscription.find_by(id: subscription_id)
        return if sub.nil?
        ActsAsTenant.with_tenant(sub.cluster) { sub.sync! }
      end
    end
  end
end
