# frozen_string_literal: true

module Stripe
  # Receives Stripe webhooks. Lives on the apex domain and is authenticated by Stripe
  # signature verification rather than by session. This class reopens the stripe gem's
  # Stripe namespace.
  class WebhooksController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :verify_authenticity_token
    skip_after_action :verify_pundit_authorization

    def create
      payload = request.body.read
      event = construct_event(payload)
      return head(:bad_request) if event.nil?

      # Log on entry with safe identifiers only (no PII / no payload dump).
      Rails.logger.info("Stripe webhook received: id=#{event.id} type=#{event.type}")

      # Persist the raw payload for debugging before doing any processing.
      WebhookEvent.record!(event, JSON.parse(payload))

      case event.type
      when "invoice.paid"
        TopupProcessor.new(event).process
        enqueue_sync(event.data.object.subscription)
      when "invoice.payment_failed", "invoice.payment_action_required", "invoice.finalized"
        enqueue_sync(event.data.object.subscription)
      when "customer.subscription.created", "customer.subscription.updated", "customer.subscription.deleted"
        enqueue_sync(event.data.object.id)
      end

      head(:ok)
    end

    protected

    # Stripe posts to a fixed apex URL with no community subdomain.
    def apex_domain_only
      true
    end

    private

    # Enqueues a cache refresh for the subscription a webhook event affects. Maps the Stripe
    # subscription id back to our record (across tenants), mirroring TopupProcessor. A no-op when
    # the id is blank or unknown to us. customer.subscription.updated is the catch-all that fires
    # when ACH clears (incomplete -> active) and when microdeposit verification completes.
    def enqueue_sync(stripe_subscription_id)
      return if stripe_subscription_id.blank?
      subscription = ActsAsTenant.without_tenant do
        ::Subscription::Subscription.find_by(stripe_id: stripe_subscription_id)
      end
      ::Subscription::SyncJob.perform_later(subscription.id) if subscription
    end

    def construct_event(payload)
      ::Stripe::Webhook.construct_event(
        payload,
        request.headers["Stripe-Signature"],
        Settings.stripe.webhook_signing_secret
      )
    rescue JSON::ParserError, ::Stripe::SignatureVerificationError => e
      Rails.logger.warn("Stripe webhook rejected: #{e.class}")
      nil
    end
  end
end
