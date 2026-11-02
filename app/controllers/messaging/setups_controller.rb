# frozen_string_literal: true

module Messaging
  # Setting up texting: registration details, the monthly package, and one payment. See SetupForm.
  class SetupsController < ApplicationController
    include SetupCheckable

    before_action -> { nav_context(:messaging, :settings) }
    before_action :verify_messaging_enabled

    def new
      authorize_setup
      @setup = SetupForm.new(community: current_community, user: current_user,
        subscription: setup_subscription)
    end

    def create
      authorize_setup
      @setup = SetupForm.new(community: current_community, user: current_user,
        subscription: setup_subscription, params: params.require(:messaging_registration))
      if @setup.save
        flash[:success] = t(".success")
        redirect_to(messaging_settings_path)
      else
        render(:new, status: :unprocessable_entity)
      end
    end

    private

    # Refuses on the server whatever the settings page wouldn't have offered.
    def authorize_setup
      authorize(current_community, :administer?, policy_class: MessagingPolicy)
      raise Pundit::NotAuthorizedError, "Messaging setup unavailable: #{setup_blocker}" if setup_blocker
    end
  end
end
