# frozen_string_literal: true

module Notifications
  # Handles the List-Unsubscribe URL in configurable notification emails.
  # Mail clients' one-click unsubscribe button (RFC 8058) POSTs here, which turns the notification off.
  # Clients without one-click support open the URL in a browser instead. GET shows a confirmation page
  # rather than unsubscribing, so that link scanners and previews fetching the URL don't unsubscribe anyone.
  class UnsubscribesController < ApplicationController
    # These are public pages. Authentication comes from the signed token in the URL.
    skip_before_action :authenticate_user!
    skip_after_action :verify_pundit_authorization

    # One-click POSTs come from mail providers, so they can't carry a CSRF token.
    skip_forgery_protection only: :create

    before_action :ensure_community
    before_action :load_unsubscribe

    def show
    end

    def create
      @unsubscribe.perform!
    end

    private

    def ensure_community
      render_not_found unless current_community
    end

    def load_unsubscribe
      @unsubscribe = Unsubscribe.from_token(params[:token])
      render(:invalid, status: :not_found) if @unsubscribe.nil?
    end
  end
end
