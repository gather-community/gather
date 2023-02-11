# frozen_string_literal: true

module Subscription
  # Decorates subscriptions.
  class SubscriptionDecorator < ApplicationDecorator
    delegate_all
  end
end
