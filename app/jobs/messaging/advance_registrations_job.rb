# frozen_string_literal: true

module Messaging
  # Polls Telnyx for every 10DLC registration waiting on a step: a paid setup that hasn't been
  # submitted yet (e.g. a retry after an outage), a brand awaiting verification, or a campaign awaiting
  # carrier review. Telnyx's status webhooks will make this a backstop rather than the main path.
  class AdvanceRegistrationsJob < ApplicationJob
    def perform
      ids = ActsAsTenant.without_tenant do
        Registration.where(status: %w[brand_pending campaign_pending])
          .or(Registration.where(status: "awaiting_payment").where.not(paid_at: nil))
          .pluck(:id)
      end
      ids.each { |id| AdvanceRegistrationJob.perform_later(id) }
    end
  end
end
