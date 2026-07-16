# frozen_string_literal: true

module Subscription
  class SubscriptionsController < ApplicationController
    decorates_assigned :subscription, with: SubscriptionDecorator

    # For now, we test this flow manually. Important combinations to test:
    #   * Past start_date, card
    #   * Past start_date, ACH instant verification
    #   * Past start_date, ACH manual
    #   * Past start_date, ACSS instant verification
    #   * Past start_date, ACSS manual
    #   * Future start_date, card
    #   * Future start_date, ACH
    #   * Today start_date, card
    #   * Today start_date, ACH
    #   * Error flows (see conditional branches in show.html.erb)
    #
    # To get the manual verification URL:
    #   Subscription::Subscription.first.populate.latest_invoice.payment_intent
    #     .next_action.verify_with_microdeposits.hosted_verification_url
    #
    # Test numbers:
    #   * ACH: https://stripe.com/docs/payments/ach-debit#test-account-numbers
    #   * ACSS: https://stripe.com/docs/billing/subscriptions/acss-debit#test-integration

    def show
      @subscription = load_auth_and_populate_subscription(or_initialize: true)

      # The monthly messaging topup is its own Stripe subscription; load it (live) for the Messaging
      # section rendered on the post-payment view. Skipped (along with its Stripe call) while
      # messaging is behind its flag.
      return unless FeatureFlag.lookup("messaging").on?(current_user)
      @messaging_topup = current_community.messaging_topup&.tap(&:populate)
      @messaging_account = current_community.messaging_account
    end

    # Self-serve signup: pick a plan and enter a billing address. Reached when the community has no
    # subscription, or has one that's dead (canceled / incomplete_expired) and needs a fresh start.
    def new
      authorize(Subscription.find_or_initialize_by(community: current_community), :new?)
      @form = SignupForm.new(community: current_community)
    end

    def create
      authorize(Subscription.find_or_initialize_by(community: current_community), :create?)
      @form = SignupForm.new(community: current_community, params: params.require(:subscription_signup))
      # save registers the subscription with Stripe (replacing any dead one), after which the
      # customer pays on the existing payment page.
      if @form.save
        redirect_to(subscription_payment_path)
      else
        render(:new, status: :unprocessable_entity)
      end
    end

    def start_payment
      subscription = load_auth_and_populate_subscription(or_initialize: true)
      if subscription.new_record? || subscription.dead?
        # Nothing to pay against — send them through self-serve signup to create a fresh sub.
        redirect_to(subscription_new_path) and return
      elsif !(subscription.needs_payment_method? || subscription.payable_invoice?)
        raise "Invalid subscription status #{subscription.status}"
      end
      redirect_to(subscription_payment_path)
    end

    def payment
      @subscription = load_auth_and_populate_subscription
      @acss_debit_mode = @subscription.payment_method_types.include?("acss_debit")
    end

    # This is where Stripe will redirect users upon successful payment.
    # The request comes with a bunch of stuff in the query string that we don't care about.
    # We just want to redirect back to the show action to clear out the query string.
    def success
      skip_authorization
      redirect_to(subscription_path)
    end

    private

    def load_auth_and_populate_subscription(or_initialize: false)
      subscription = if or_initialize
                        Subscription.find_or_initialize_by(community: current_community)
                      else
                        Subscription.find_by!(community: current_community)
                      end
      authorize(subscription)
      Sentry.configure_scope do |scope|
        scope.set_context("subscription", stripe_subscription_id: subscription.stripe_id)
      end
      # sync! fetches live from Stripe (populating stripe_sub for this request) and write-caches the
      # status locally. New/unpersisted subscriptions short-circuit inside sync! and skip the fetch.
      subscription.sync!
      subscription
    end
  end
end
