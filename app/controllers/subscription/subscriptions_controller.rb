# frozen_string_literal: true

module Subscription
  class SubscriptionsController < ApplicationController
    def show
      @subscription = Subscription.find_or_initialize_by(community: current_community)
      authorize(@subscription)
    end

    def start_payment
      @subscription = Subscription.find_by!(community: current_community)
      authorize(@subscription)
      Registrar.new(subscription: @subscription).register
      redirect_to(subscription_payment_subscription_path)
    end

    def payment
      @subscription = Subscription.find_by!(community: current_community)
      authorize(@subscription)
      stripe_subscription = Stripe::Subscription.retrieve(
        id: @subscription.stripe_id,
        expand: ["latest_invoice.payment_intent"]
      )
      @client_secret = stripe_subscription.latest_invoice.payment_intent.client_secret
    end
  end
end