# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  def show
    load_and_auth_subscription
  end

  def start_payment
    load_and_auth_subscription
    redirect_to(payment_subscription_path)
  end

  def payment
    load_and_auth_subscription
  end

  private

  def load_and_auth_subscription
    @subscription = Subscription.find_or_initialize_by(community: current_community)
    authorize(@subscription)
  end
end
