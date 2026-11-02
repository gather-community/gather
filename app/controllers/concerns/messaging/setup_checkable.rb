# frozen_string_literal: true

module Messaging
  # What texting setup needs before it can be offered, shared by the settings page (which explains
  # what's missing) and the setup page (which refuses without it).
  module SetupCheckable
    extend ActiveSupport::Concern

    private

    # Gate both the UI and the endpoints on the flag.
    def verify_messaging_enabled
      raise Pundit::NotAuthorizedError unless FeatureFlag.lookup("messaging").on?(current_user)
    end

    # Why setup can't be offered right now, as a symbol, or nil if it can. Populates the base
    # subscription from Stripe, so only call it when setup might be offered.
    def setup_blocker
      return @setup_blocker if defined?(@setup_blocker)
      @setup_blocker =
        if !current_community.messaging_supported? then :unsupported
        elsif current_community.messaging_registration&.paid? then :already_paid
        elsif !setup_subscription&.messaging_chargeable? then :no_subscription
        # A monthly package started before setup existed. Setup starts a new one, so the old one has to
        # go first. Rare: the package was only offered behind the same feature flag.
        elsif current_community.messaging_topup.present? then :topup_exists
        end
    end

    def setup_subscription
      return @setup_subscription if defined?(@setup_subscription)
      @setup_subscription = Subscription::Subscription.find_by(community: current_community)&.tap(&:populate)
    end
  end
end
