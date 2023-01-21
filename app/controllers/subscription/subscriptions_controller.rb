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
      redirect_to(subscription_payment_subscription_path)
    end

    def payment
      @subscription = Subscription.find_by!(community: current_community)
      authorize(@subscription)
    end
  end
end