# frozen_string_literal: true

module Messaging
  # The texting settings page: the community's setup status, and the way into setup.
  class SettingsController < ApplicationController
    include SetupCheckable

    before_action -> { nav_context(:messaging, :settings) }
    before_action :verify_messaging_enabled

    def show
      authorize(current_community, :administer?, policy_class: MessagingPolicy)
      @registration = current_community.messaging_registration
      @account = current_community.messaging_account
      @setup_blocker = setup_blocker unless @registration&.paid?
    end
  end
end
