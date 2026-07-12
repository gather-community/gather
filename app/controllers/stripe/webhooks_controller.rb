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

      handle_event(event)
      head(:ok)
    end

    protected

    # Stripe posts to a fixed apex URL with no community subdomain.
    def apex_domain_only
      true
    end

    private

    def handle_event(event)
      case event.type
      when "invoice.finalized"
        # Credit the messaging wallet as soon as the invoice is finalized, before payment clears, so
        # slow ACH payments don't delay usable credit. (The save flow also credits synchronously;
        # this is the idempotent backstop for that and the source of truth for cycle renewals.)
        TopupProcessor.new(event.data.object, event: event).credit
        enqueue_sync(event.data.object.subscription)
      when "invoice.marked_uncollectible", "invoice.voided"
        # Stripe gave up collecting: reverse any messaging credit we made for this invoice.
        TopupProcessor.new(event.data.object, event: event).reverse
        enqueue_sync(event.data.object.subscription)
      when "invoice.paid", "invoice.payment_failed", "invoice.payment_action_required"
        enqueue_sync(event.data.object.subscription)
      when "customer.subscription.deleted"
        # If a topup sub was canceled with an unpaid invoice (Stripe's default failed-payment action),
        # reverse and void it. No-op for a canceled base subscription.
        TopupProcessor.handle_topup_cancellation(event.data.object.id)
        enqueue_sync(event.data.object.id)
      when "customer.subscription.created", "customer.subscription.updated"
        enqueue_sync(event.data.object.id)
      end
    end

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
