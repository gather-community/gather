# frozen_string_literal: true

module Subscription
  class SubscriptionsController < ApplicationController
    decorates_assigned :subscription, :intent, with: SubscriptionDecorator

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

      if @subscription.new_record? || @subscription.incomplete_expired?
        @intent = Intent.find_by(community: current_community)
      end
    end

    def start_payment
      subscription = load_auth_and_populate_subscription(or_initialize: true)
      if subscription.active? && subscription.needs_payment_method?
        # No action needed here, we just redirect.
      elsif subscription.new_record? || subscription.incomplete_expired?
        intent = Intent.find_by!(community: current_community)
        Registrar.new(intent: intent).register
      elsif !(subscription.incomplete? || subscription.past_due?)
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
      subscription.populate
      subscription
    end
  end
end
