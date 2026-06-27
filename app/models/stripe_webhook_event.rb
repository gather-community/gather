# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_webhook_events
#
#  id         :bigint           not null, primary key
#  event_id   :string
#  event_type :string
#  payload    :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Stores raw, signature-verified Stripe webhook payloads for prod debugging. Persisted on
# receipt, before processing. Deliberately NOT tenant-scoped (named without a `Stripe`
# module to avoid clashing with the stripe gem's `Stripe` constant): the cluster isn't known
# until processing resolves the subscription, and some events never map to a subscription.
#
# Note: payloads may contain customer PII (email, address). They live only in our DB, never
# in logs or Sentry.
class StripeWebhookEvent < ApplicationRecord
  validates :payload, presence: true

  # Records an authentic (signature-verified) Stripe event before it is processed.
  def self.record!(event, payload)
    create!(event_id: event.id, event_type: event.type, payload: payload)
  end
end
