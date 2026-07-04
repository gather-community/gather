# frozen_string_literal: true

module Subscription
  # Nightly job that refreshes every community's cached subscription status from Stripe so the
  # /communities index and community status stay fresh. sync! swallows and reports Stripe errors,
  # so one failing subscription doesn't abort the run.
  class SyncAllJob < ApplicationJob
    def perform
      each_community do |community|
        community.subscription&.sync!
      end
    end
  end
end
