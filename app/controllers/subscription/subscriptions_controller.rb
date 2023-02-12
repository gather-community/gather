# frozen_string_literal: true

module Subscription
  class SubscriptionsController < ApplicationController
    decorates_assigned :subscription, :intent, with: SubscriptionDecorator

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
        scope.set_context("character", stripe_subscription_id: subscription.stripe_id)
      end
      subscription.populate
      subscription
    end
  end
end