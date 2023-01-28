# frozen_string_literal: true

module Subscription
  class SubscriptionsController < ApplicationController
    def show
      @subscription = Subscription.find_or_initialize_by(community: current_community)
      @subscription.populate
      authorize(@subscription)

      if @subscription.new_record? || @subscription.incomplete_expired?
        @intent = Intent.find_by(community: current_community)
      end
    end

    def start_payment
      subscription = Subscription.find_or_initialize_by(community: current_community)
      authorize(subscription, policy_class: SubscriptionPolicy)
      subscription.populate
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
      @subscription = Subscription.find_by!(community: current_community)
      authorize(@subscription)
      @subscription.populate
    end

    def success
      @subscription = Subscription.find_by!(community: current_community)
      authorize(@subscription)
      flash[:success] = "Your subscription was successfully paid and is now active!"
      redirect_to(subscription_path)
    end
  end
end