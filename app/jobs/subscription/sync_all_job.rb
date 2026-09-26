# frozen_string_literal: true

module Subscription
  # Nightly job that refreshes every community's cached subscription status from Stripe so the
  # /communities index and community status stay fresh. sync! swallows and reports Stripe errors,
  # so one failing subscription doesn't abort the run.
  class SyncAllJob < ApplicationJob
    def perform
      each_community do |community|
        community.subscription&.sync!
        reap_ended_topup(community)
      end
    end

    private

    # Backstop for a missed customer.subscription.deleted: clears a local topup row whose Stripe
    # subscription has already ended, which reads back as a healthy active topup and would otherwise
    # be shown as live indefinitely. Stripe errors are reported rather than raised so one community
    # can't abort the run, mirroring sync!.
    def reap_ended_topup(community)
      community.messaging_topup&.reap_if_canceled!
    rescue Stripe::StripeError => e
      Gather::ErrorReporter.instance.report(e, data: {community_id: community.id})
    end
  end
end
