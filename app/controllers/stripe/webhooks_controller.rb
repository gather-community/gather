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

      # Persist the raw payload for debugging before doing any processing. Then emit a greppable line
      # tying this webhook to a community; the full payload lives in the DB by webhook_id.
      WebhookEvent.record!(event, JSON.parse(payload))
      log_webhook_arrival(event)

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
      object = event.data.object
      case object.object
      when "invoice"
        reconcile_topup(event, object)
        enqueue_sync(object.subscription)
      when "subscription"
        enqueue_sync(object.id)
      end
    end

    # Drives the wallet from the invoice's payment lifecycle (see TopupProcessor). Non-topup invoices
    # are a no-op inside the processor.
    def reconcile_topup(event, invoice)
      processor = TopupProcessor.new(invoice, event: event)
      case event.type
      when "invoice.finalized" then processor.credit_if_settled_or_in_flight
      when "invoice.paid" then processor.credit
      when "invoice.payment_failed", "invoice.voided", "invoice.marked_uncollectible" then processor.claw_back
      end
    end

    # Emits a SUBSCRIPTION-EVENT-LINE tying this webhook to a community (resolved from the base
    # subscription or the topup subscription id), so it's searchable in BetterStack.
    def log_webhook_arrival(event)
      ::Subscription::EventLog.emit(
        event_name: "webhook_arrived",
        community_id: community_id_for(event),
        webhook_type: event.type,
        webhook_id: event.id
      )
    end

    def community_id_for(event)
      object = event.data.object
      sub_id = case object.object
      when "invoice" then object.subscription
      when "subscription" then object.id
      end
      return nil if sub_id.blank?
      ActsAsTenant.without_tenant do
        (::Subscription::Subscription.find_by(stripe_id: sub_id) ||
          ::Subscription::MessagingTopup.find_by(stripe_id: sub_id))&.community_id
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
